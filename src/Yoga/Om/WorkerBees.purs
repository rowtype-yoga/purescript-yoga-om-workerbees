module Yoga.Om.WorkerBees
  ( WorkerPool
  , PoolConfig
  , defaultPoolConfig
  , makePool
  , makePoolWithData
  , terminatePool
  , distributeWork
  , module Exports
  , module SharedInt
  , module SharedState
  , module SharedMap
  ) where

import Prelude

import Control.Parallel (parTraverse)
import Data.Traversable (class Traversable)
import Node.WorkerBees (Worker, class Sendable) as Exports
import Node.WorkerBees as WB
import Node.WorkerBees.Aff.Pool as Pool
import Yoga.Om (Om)
import Yoga.Om as Om
import Yoga.Om.WorkerBees.SharedInt (SharedInt) as SharedInt
import Yoga.Om.WorkerBees.SharedState (SharedState) as SharedState
import Yoga.Om.WorkerBees.SharedMap (SharedMap) as SharedMap

-- | Configuration for a worker pool
type PoolConfig =
  { numWorkers :: Int
  , workerPath :: String
  }

-- | Default pool configuration (4 workers)
defaultPoolConfig :: String -> PoolConfig
defaultPoolConfig workerPath =
  { numWorkers: 4
  , workerPath
  }

-- | Worker pool handle
type WorkerPool input output = Pool.WorkerPool input output

-- | Create a worker pool. Must be paired with `terminatePool`.
makePool
  :: forall ctx errs input output
   . WB.Sendable input
  => WB.Sendable output
  => PoolConfig
  -> Om ctx errs (WorkerPool input output)
makePool config = Om.fromAff do
  let worker = WB.unsafeWorkerFromPath config.workerPath
  Pool.make worker unit config.numWorkers

-- | Create a worker pool with shared data accessible to all workers via `workerData`.
makePoolWithData
  :: forall ctx errs input output a
   . WB.Sendable input
  => WB.Sendable output
  => WB.Sendable a
  => PoolConfig
  -> a
  -> Om ctx errs (WorkerPool input output)
makePoolWithData config workerData = Om.fromAff do
  let worker = WB.unsafeWorkerFromPath config.workerPath
  Pool.make worker workerData config.numWorkers

-- | Terminate a worker pool and all its threads.
terminatePool
  :: forall ctx errs input output
   . WorkerPool input output
  -> Om ctx errs Unit
terminatePool pool = Om.fromAff do
  Pool.terminate pool

-- | Distribute work across the worker pool in parallel.
-- | Each input is submitted to the pool and processed by the next available worker.
distributeWork
  :: forall ctx errs f input output
   . Traversable f
  => WB.Sendable input
  => WorkerPool input output
  -> f input
  -> Om ctx errs (f output)
distributeWork pool inputs = Om.fromAff do
  parTraverse (Pool.invoke pool) inputs
