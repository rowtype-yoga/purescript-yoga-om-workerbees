module Yoga.Om.WorkerBees.SharedMap
  ( SharedMap
  , new
  , lookup
  , insert
  , delete
  , modify
  , toSendable
  , fromSendable
  ) where

import Prelude

import Data.Array as Array
import Data.ArrayBuffer.Types (Int32Array)
import Data.Function.Uncurried (Fn1, Fn2, runFn1, runFn2)
import Data.Maybe (Maybe(..))
import Data.Traversable (for)
import Data.Either (Either(..))
import Effect (Effect)
import Effect.Exception (throw, throwException, try)
import Effect.Uncurried (EffectFn2, EffectFn3, runEffectFn2, runEffectFn3)
import Foreign.Object as FObject
import Partial.Unsafe (unsafeCrashWith)
import Node.WorkerBees (SendWrapper, unsafeWrap)
import Node.WorkerBees as WB
import Yoga.JSON (class ReadForeign, class WriteForeign, readJSON_, writeJSON)
import Yoga.Om.WorkerBees.Atomics as Atomics
import Yoga.Om.WorkerBees.SharedArrayBuffer as SAB
import Yoga.Om.WorkerBees.SharedArrayBuffer (SharedArrayBuffer)

-- | Memory layout:
-- | Bytes 0-3: numSegments (Int32)
-- | Bytes 4-7: maxBytesPerSegment (Int32)
-- | Then N segments, each: [lock: 4B] [len: 4B] [JSON data: maxBytesPerSegment]

type Segment =
  { lock :: Int32Array
  , lenSlot :: Int32Array
  , dataOffset :: Int
  }

-- | A shared concurrent map backed by SharedArrayBuffer with striped locks.
-- | Keys are Strings, values must be JSON-serializable.
-- | The keyspace is split into N segments for N-way concurrency.
newtype SharedMap :: Type -> Type
newtype SharedMap a = SharedMap
  { sab :: SharedArrayBuffer
  , numSegments :: Int
  , maxBytesPerSegment :: Int
  , segments :: Array Segment
  }

headerBytes :: Int
headerBytes = 8

segmentHeaderBytes :: Int
segmentHeaderBytes = 8

-- | Create a new empty SharedMap.
-- | `numSegments` controls concurrency (e.g., 16 or 64).
-- | `maxBytesPerSegment` is the max JSON size per segment.
new :: forall a. Int -> Int -> Effect (SharedMap a)
new numSegments maxBytesPerSegment = do
  let segmentSize = segmentHeaderBytes + maxBytesPerSegment
  let totalBytes = headerBytes + numSegments * segmentSize
  sab <- SAB.new totalBytes
  -- Write header (use Int32Array view over first 8 bytes)
  headerView <- SAB.toInt32ArraySlice sab 0 2
  _ <- Atomics.store headerView 0 numSegments
  _ <- Atomics.store headerView 1 maxBytesPerSegment
  -- Initialize segments with empty objects
  segments <- for (Array.range 0 (numSegments - 1)) \i -> do
    let base = headerBytes + i * segmentSize
    lock <- SAB.toInt32ArraySlice sab base 1
    lenSlot <- SAB.toInt32ArraySlice sab (base + 4) 1
    let dataOffset = base + segmentHeaderBytes
    let json = "{}"
    len <- runEffectFn3 writeSegmentDataImpl sab dataOffset json
    _ <- Atomics.store lenSlot 0 len
    pure { lock, lenSlot, dataOffset }
  pure (SharedMap { sab, numSegments, maxBytesPerSegment, segments })

-- | Look up a key. Returns Nothing if not found.
lookup :: forall a. ReadForeign a => String -> SharedMap a -> Effect (Maybe a)
lookup key m = do
  let seg = segmentFor key m
  withLock seg do
    obj <- readSegment m seg
    pure (FObject.lookup key obj)

-- | Insert or overwrite a key-value pair.
insert :: forall a. ReadForeign a => WriteForeign a => String -> a -> SharedMap a -> Effect Unit
insert key val m = do
  let seg = segmentFor key m
  withLock seg do
    obj <- readSegment m seg
    writeSegment m seg (FObject.insert key val obj)

-- | Delete a key. No-op if key doesn't exist.
delete :: forall a. ReadForeign a => WriteForeign a => String -> SharedMap a -> Effect Unit
delete key m = do
  let seg = segmentFor key m
  withLock seg do
    obj <- readSegment m seg
    writeSegment m seg (FObject.delete key obj)

-- | Atomically modify the value at a key. Returns the new value, or Nothing if not found.
modify :: forall a. ReadForeign a => WriteForeign a => String -> (a -> a) -> SharedMap a -> Effect (Maybe a)
modify key f m = do
  let seg = segmentFor key m
  withLock seg do
    obj <- readSegment m seg
    case FObject.lookup key obj of
      Nothing -> pure Nothing
      Just val -> do
        let next = f val
        writeSegment m seg (FObject.insert key next obj)
        pure (Just next)

-- | Wrap for worker transfer.
toSendable :: forall a. SharedMap a -> SendWrapper (SharedMap a)
toSendable = unsafeWrap

-- | Unwrap on the worker side. Reconstructs Int32Array views from the shared buffer.
fromSendable :: forall a. SendWrapper (SharedMap a) -> Effect (SharedMap a)
fromSendable sw = do
  let (SharedMap s) = WB.unwrap sw
  ns <- runEffectFn2 readInt32Impl s.sab 0
  mbs <- runEffectFn2 readInt32Impl s.sab 4
  let segmentSize = segmentHeaderBytes + mbs
  segments <- for (Array.range 0 (ns - 1)) \i -> do
    let base = headerBytes + i * segmentSize
    lock <- SAB.toInt32ArraySlice s.sab base 1
    lenSlot <- SAB.toInt32ArraySlice s.sab (base + 4) 1
    let dataOffset = base + segmentHeaderBytes
    pure { lock, lenSlot, dataOffset }
  pure (SharedMap { sab: s.sab, numSegments: ns, maxBytesPerSegment: mbs, segments })

-- Internal helpers

segmentFor :: forall a. String -> SharedMap a -> Segment
segmentFor key (SharedMap { numSegments, segments }) = do
  let idx = runFn2 hashKeyImpl key numSegments
  case Array.index segments idx of
    Just seg -> seg
    Nothing -> unsafeCrashWith "SharedMap: hash out of range"

withLock :: forall a. Segment -> Effect a -> Effect a
withLock seg action = do
  acquireLock seg
  result <- try action
  releaseLock seg
  case result of
    Right val -> pure val
    Left err -> throwException err

acquireLock :: Segment -> Effect Unit
acquireLock { lock } = go
  where
  go = do
    old <- Atomics.compareExchange lock 0 0 1
    when (old /= 0) go

releaseLock :: Segment -> Effect Unit
releaseLock { lock } = void $ Atomics.store lock 0 0

readSegment :: forall a. ReadForeign a => SharedMap a -> Segment -> Effect (FObject.Object a)
readSegment (SharedMap { sab }) { lenSlot, dataOffset } = do
  len <- Atomics.load lenSlot 0
  json <- runEffectFn3 readSegmentDataImpl sab dataOffset len
  case readJSON_ json of
    Just obj -> pure obj
    Nothing -> throw "SharedMap: failed to deserialize segment"

writeSegment :: forall a. WriteForeign a => SharedMap a -> Segment -> FObject.Object a -> Effect Unit
writeSegment (SharedMap { sab, maxBytesPerSegment }) { lenSlot, dataOffset } obj = do
  let json = writeJSON obj
  let len = runFn1 stringByteLengthImpl json
  when (len > maxBytesPerSegment) do
    throw "SharedMap: segment data exceeds maxBytesPerSegment"
  _ <- runEffectFn3 writeSegmentDataImpl sab dataOffset json
  void $ Atomics.store lenSlot 0 len

foreign import hashKeyImpl :: Fn2 String Int Int
foreign import writeSegmentDataImpl :: EffectFn3 SharedArrayBuffer Int String Int
foreign import readSegmentDataImpl :: EffectFn3 SharedArrayBuffer Int Int String
foreign import readInt32Impl :: EffectFn2 SharedArrayBuffer Int Int
foreign import stringByteLengthImpl :: Fn1 String Int
