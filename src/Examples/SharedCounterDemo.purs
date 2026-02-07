module Examples.SharedCounterDemo where

import Prelude

import Prelude

import Control.Parallel (parTraverse)
import Data.Array as Array
import Data.Traversable (for_)
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Effect.Class (liftEffect)
import Effect.Class.Console (log)
import Node.WorkerBees.Aff.Pool as Pool
import Node.WorkerBees as WB
import Yoga.Om.WorkerBees.SharedInt as SharedInt

-- | Console demo of SharedInt (atomic counter) across worker threads
-- |
-- | This demonstrates:
-- | - Creating a shared atomic counter
-- | - Passing shared memory to workers via workerData
-- | - Concurrent increments from multiple workers
-- | - Reading the final value
type CounterInput = { n :: Int }
type CounterOutput = { result :: Int, count :: Int }

counterDemo :: Aff Unit
counterDemo = do
  log "=== Shared Counter Demo ==="
  log ""

  -- Create shared counter starting at 0
  log "Creating shared counter..."
  counter <- liftEffect $ SharedInt.new 0

  -- Create worker pool with shared counter as workerData
  log "Creating worker pool with shared counter..."
  let counterSendable = SharedInt.toSendable counter
  let worker = (WB.unsafeWorkerFromPath "./dist/workers/CounterWorker.js" :: WB.Worker (WB.SendWrapper SharedInt.SharedInt) CounterInput CounterOutput)
  pool <- Pool.make worker counterSendable 4

  -- Send 100 increment tasks (each worker will increment the shared counter)
  let tasks = Array.range 1 100
  let counterInputs = map (\n -> { n }) tasks

  log "Distributing 100 increment tasks across workers..."
  log ""

  results <- parTraverse (Pool.invoke pool) counterInputs

  -- Print some sample results (showing concurrent increments)
  log "Sample results from workers:"
  for_ (Array.take 10 results) \result -> do
    log $ "  Result: " <> show result.result <> ", Counter: " <> show result.count

  log "..."
  log ""

  -- Read final counter value
  finalValue <- liftEffect $ SharedInt.read counter
  log $ "Final counter value: " <> show finalValue

  log ""
  log "Cleaning up..."
  Pool.terminate pool

  log "Done!"

main :: Effect Unit
main = launchAff_ counterDemo
