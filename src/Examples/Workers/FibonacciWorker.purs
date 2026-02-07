module Examples.Workers.FibonacciWorker where

import Prelude

import Effect (Effect)
import Node.WorkerBees as WB

-- | Input type for the worker
type FibInput = { n :: Int }

-- | Output type for the worker
type FibOutput = { result :: Int, thread :: Int }

-- | CPU-intensive Fibonacci calculation (intentionally inefficient for demo)
fibonacci :: Int -> Int
fibonacci n
  | n <= 1 = n
  | otherwise = fibonacci (n - 1) + fibonacci (n - 2)

-- | Worker main function
-- | This receives inputs and sends back outputs
worker :: WB.WorkerContext Unit FibInput FibOutput -> Effect Unit
worker ctx = ctx.receive \{ n } -> do
  let result = fibonacci n
  -- Could get thread ID from ctx.threadId if needed
  ctx.reply { result, thread: 0 }

-- | Entry point for the worker
-- | This must be the main function when bundled
main :: Effect Unit
main = WB.makeAsMain worker
