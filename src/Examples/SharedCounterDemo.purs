module Examples.SharedCounterDemo where

import Prelude

import Control.Monad.Error.Class (throwError)
import Data.Array as Array
import Data.Traversable (for_)
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Class.Console (log)
import Yoga.Om as Om
import Yoga.Om.WorkerBees (WorkerPool, makePoolWithData, distributeWork, terminatePool)
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

counterDemo :: forall ctx. Om.Om ctx () Unit
counterDemo = do
  Om.fromAff $ log "=== Shared Counter Demo ==="
  Om.fromAff $ log ""

  -- Create shared counter starting at 0
  Om.fromAff $ log "Creating shared counter..."
  counter <- Om.fromAff $ liftEffect $ SharedInt.new 0

  -- Create worker pool with shared counter as workerData (Om API)
  Om.fromAff $ log "Creating worker pool with shared counter..."
  pool <- (makePoolWithData
    { workerPath: "./dist/workers/CounterWorker.js"
    , numWorkers: 4
    }
    (SharedInt.toSendable counter) :: Om.Om ctx () (WorkerPool CounterInput CounterOutput))

  -- Send 100 increment tasks (each worker will increment the shared counter)
  let tasks = Array.range 1 100
  let counterInputs = map (\n -> { n }) tasks

  Om.fromAff $ log "Distributing 100 increment tasks across workers..."
  Om.fromAff $ log ""

  results <- distributeWork pool counterInputs

  -- Print some sample results (showing concurrent increments)
  Om.fromAff $ log "Sample results from workers:"
  Om.fromAff $ for_ (Array.take 10 results) \result -> do
    log $ "  Result: " <> show result.result <> ", Counter: " <> show result.count

  Om.fromAff $ log "..."
  Om.fromAff $ log ""

  -- Read final counter value
  finalValue <- Om.fromAff $ liftEffect $ SharedInt.read counter
  Om.fromAff $ log $ "Final counter value: " <> show finalValue

  Om.fromAff $ log ""
  Om.fromAff $ log "Cleaning up..."
  terminatePool pool

  Om.fromAff $ log "Done!"

main :: Effect Unit
main = launchAff_ $ Om.runOm unit { exception: throwError } counterDemo
