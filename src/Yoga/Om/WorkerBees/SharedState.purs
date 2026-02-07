module Yoga.Om.WorkerBees.SharedState
  ( SharedState
  , new
  , read
  , write
  , modify
  , toSendable
  , fromSendable
  ) where

import Prelude

import Data.ArrayBuffer.Types (Int32Array)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Exception (throw, throwException, try)
import Effect.Uncurried (EffectFn2, runEffectFn2)
import Node.WorkerBees (SendWrapper, unsafeWrap)
import Node.WorkerBees as WB
import Yoga.JSON (class ReadForeign, class WriteForeign, readJSON_, writeJSON)
import Yoga.Om.WorkerBees.Atomics as Atomics
import Yoga.Om.WorkerBees.SharedArrayBuffer as SAB
import Yoga.Om.WorkerBees.SharedArrayBuffer (SharedArrayBuffer)

-- | Buffer layout:
-- | - Int32 slot 0 (bytes 0..3): mutex lock (0 = unlocked, 1 = locked)
-- | - Int32 slot 1 (bytes 4..7): data length in bytes
-- | - Bytes 8..N: UTF-8 encoded JSON string

-- | A shared mutable state that can be accessed from multiple worker threads.
-- | Values are JSON-serialized into a SharedArrayBuffer with a spinlock mutex.
newtype SharedState :: Type -> Type
newtype SharedState a = SharedState
  { lock :: Int32Array
  , lenSlot :: Int32Array
  , sab :: SharedArrayBuffer
  , maxBytes :: Int
  }

-- | Create a new SharedState with an initial value.
-- | `maxBytes` is the maximum size for the serialized JSON data.
new :: forall a. WriteForeign a => Int -> a -> Effect (SharedState a)
new maxBytes initial = do
  let totalBytes = 8 + maxBytes
  sab <- SAB.new totalBytes
  lock <- SAB.toInt32ArraySlice sab 0 1
  lenSlot <- SAB.toInt32ArraySlice sab 4 1
  let json = writeJSON initial
  len <- runEffectFn2 writeDataImpl sab json
  _ <- Atomics.store lenSlot 0 len
  pure (SharedState { lock, lenSlot, sab, maxBytes })

-- | Atomically read the current state.
read :: forall a. ReadForeign a => SharedState a -> Effect a
read state = withLock state do
  readData state

-- | Atomically write a new state value.
write :: forall a. WriteForeign a => SharedState a -> a -> Effect Unit
write state val = withLock state do
  writeData state val

-- | Atomically modify the state. Returns the new value.
modify :: forall a. ReadForeign a => WriteForeign a => SharedState a -> (a -> a) -> Effect a
modify state f = withLock state do
  current <- readData state
  let next = f current
  writeData state next
  pure next

-- | Wrap for worker transfer. The underlying SharedArrayBuffer is shared.
toSendable :: forall a. SharedState a -> SendWrapper (SharedState a)
toSendable = unsafeWrap

-- | Unwrap on the worker side. Reconstructs Int32Array views from the shared buffer.
fromSendable :: forall a. SendWrapper (SharedState a) -> Effect (SharedState a)
fromSendable sw = do
  let (SharedState s) = WB.unwrap sw
  lock <- SAB.toInt32ArraySlice s.sab 0 1
  lenSlot <- SAB.toInt32ArraySlice s.sab 4 1
  pure (SharedState { lock, lenSlot, sab: s.sab, maxBytes: s.maxBytes })

-- Internal: spinlock

withLock :: forall a b. SharedState a -> Effect b -> Effect b
withLock state action = do
  acquireLock state
  result <- try action
  releaseLock state
  case result of
    Right val -> pure val
    Left err -> throwException err

acquireLock :: forall a. SharedState a -> Effect Unit
acquireLock (SharedState { lock }) = go
  where
  go = do
    old <- Atomics.compareExchange lock 0 0 1
    when (old /= 0) go

releaseLock :: forall a. SharedState a -> Effect Unit
releaseLock (SharedState { lock }) = void $ Atomics.store lock 0 0

-- Internal: data read/write (must hold lock)

writeData :: forall a. WriteForeign a => SharedState a -> a -> Effect Unit
writeData (SharedState { sab, lenSlot }) val = do
  let json = writeJSON val
  len <- runEffectFn2 writeDataImpl sab json
  void $ Atomics.store lenSlot 0 len

readData :: forall a. ReadForeign a => SharedState a -> Effect a
readData (SharedState { sab, lenSlot }) = do
  len <- Atomics.load lenSlot 0
  json <- runEffectFn2 readDataImpl sab len
  case readJSON_ json of
    Just val -> pure val
    Nothing -> throw "SharedState: failed to deserialize"

-- FFI

foreign import writeDataImpl :: EffectFn2 SharedArrayBuffer String Int
foreign import readDataImpl :: EffectFn2 SharedArrayBuffer Int String
