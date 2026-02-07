module Examples.FibonacciDemo where

import Prelude

import Control.Monad.Error.Class (throwError)
import Data.Array as Array
import Data.Traversable (for_)
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class.Console (log)
import Yoga.Om as Om
import Yoga.Om.WorkerBees (WorkerPool, makePool, distributeWork, terminatePool)

-- | Simple console demo of Fibonacci calculation using worker pool
-- |
-- | This demonstrates:
-- | - Creating a worker pool
-- | - Distributing work across multiple threads
-- | - Collecting results
-- | - Proper cleanup
type FibInput = { n :: Int }
type FibOutput = { result :: Int, thread :: Int }

fibDemo :: Om.Om Unit () Unit
fibDemo = do
  Om.fromAff $ log "=== Fibonacci Worker Demo ==="
  Om.fromAff $ log ""

  -- Create worker pool with 4 workers (Om API, no shared context needed)
  Om.fromAff $ log "Creating worker pool..."
  (pool :: WorkerPool FibInput FibOutput) <- makePool
    { workerPath: "./dist/workers/FibonacciWorker.js"
    , numWorkers: 4
    }

  -- Test inputs: Calculate Fibonacci for these numbers
  let inputs = [35, 36, 37, 38, 39, 40]
  let fibInputs = map (\n -> { n }) inputs

  Om.fromAff $ log $ "Calculating Fibonacci for: " <> show inputs
  Om.fromAff $ log ""

  -- Distribute work using Om API
  results <- distributeWork pool fibInputs

  -- Print results
  Om.fromAff $ for_ (Array.zip inputs results) \(Tuple input result) -> do
    log $ "fib(" <> show input <> ") = " <> show result.result

  Om.fromAff $ log ""
  Om.fromAff $ log "Cleaning up..."
  terminatePool pool

  Om.fromAff $ log "Done!"

main :: Effect Unit
main = launchAff_ $ Om.runOm unit { exception: throwError } fibDemo
