module Yoga.Om.WorkerBees.SharedInt
  ( SharedInt
  , new
  , read
  , write
  , add
  , sub
  , compareAndSwap
  , modify
  , toSendable
  , fromSendable
  ) where

import Prelude

import Data.ArrayBuffer.Types (Int32Array)
import Effect (Effect)
import Node.WorkerBees (SendWrapper, unsafeWrap)
import Node.WorkerBees as WB
import Yoga.Om.WorkerBees.Atomics as Atomics
import Yoga.Om.WorkerBees.SharedArrayBuffer as SAB

-- | An atomic integer reference backed by SharedArrayBuffer.
-- | Can be shared across worker threads via `toSendable`/`fromSendable`.
newtype SharedInt = SharedInt Int32Array

-- | Create a new SharedInt initialized to the given value.
new :: Int -> Effect SharedInt
new initial = do
  sab <- SAB.new 4
  arr <- SAB.toInt32Array sab
  _ <- Atomics.store arr 0 initial
  pure (SharedInt arr)

-- | Atomically read the current value.
read :: SharedInt -> Effect Int
read (SharedInt arr) = Atomics.load arr 0

-- | Atomically write a new value.
write :: SharedInt -> Int -> Effect Unit
write (SharedInt arr) val = void $ Atomics.store arr 0 val

-- | Atomically add to the current value. Returns the OLD value.
add :: SharedInt -> Int -> Effect Int
add (SharedInt arr) val = Atomics.add arr 0 val

-- | Atomically subtract from the current value. Returns the OLD value.
sub :: SharedInt -> Int -> Effect Int
sub (SharedInt arr) val = Atomics.sub arr 0 val

-- | Atomic compare-and-swap. If current value equals `expected`,
-- | replace with `replacement`. Returns the old value.
compareAndSwap :: SharedInt -> Int -> Int -> Effect Int
compareAndSwap (SharedInt arr) expected replacement =
  Atomics.compareExchange arr 0 expected replacement

-- | Atomically modify the value using a CAS loop.
-- | Retries until the CAS succeeds.
modify :: SharedInt -> (Int -> Int) -> Effect Int
modify ref f = go
  where
  go = do
    current <- read ref
    let next = f current
    old <- compareAndSwap ref current next
    if old == current then pure next
    else go

-- | Wrap for sending to a worker thread.
toSendable :: SharedInt -> SendWrapper SharedInt
toSendable = unsafeWrap

-- | Unwrap after receiving on a worker thread.
fromSendable :: SendWrapper SharedInt -> SharedInt
fromSendable = WB.unwrap
