module Examples.FibonacciDemo where

import Prelude

import Prelude

import Control.Parallel (parTraverse)
import Data.Array as Array
import Data.Traversable (for_)
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Effect.Class.Console (log)
import Node.WorkerBees.Aff.Pool as Pool
import Node.WorkerBees as WB

-- | Simple console demo of Fibonacci calculation using worker pool
-- |
-- | This demonstrates:
-- | - Creating a worker pool
-- | - Distributing work across multiple threads
-- | - Collecting results
-- | - Proper cleanup
type FibInput = { n :: Int }
type FibOutput = { result :: Int, thread :: Int }

fibDemo :: Aff Unit
fibDemo = do
  log "=== Fibonacci Worker Demo ==="
  log ""

  -- Create worker pool with 4 workers
  log "Creating worker pool..."
  let worker = (WB.unsafeWorkerFromPath "./dist/workers/FibonacciWorker.js" :: WB.Worker Unit FibInput FibOutput)
  pool <- Pool.make worker unit 4

  -- Test inputs: Calculate Fibonacci for these numbers
  let inputs = [35, 36, 37, 38, 39, 40]
  let fibInputs = map (\n -> { n }) inputs

  log $ "Calculating Fibonacci for: " <> show inputs
  log ""

  -- Distribute work and collect results
  results <- parTraverse (Pool.invoke pool) fibInputs

  -- Print results
  for_ (Array.zip inputs results) \(Tuple input result) -> do
    log $ "fib(" <> show input <> ") = " <> show result.result

  log ""
  log "Cleaning up..."
  Pool.terminate pool

  log "Done!"

main :: Effect Unit
main = launchAff_ fibDemo
