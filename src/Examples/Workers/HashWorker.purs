module Examples.Workers.HashWorker where

import Prelude

import Data.Foldable (foldl)
import Data.String as String
import Data.String.CodeUnits as SCU
import Effect (Effect)
import Node.WorkerBees as WB

-- | Input type for the worker
type HashInput = { text :: String, iterations :: Int }

-- | Output type for the worker
type HashOutput = { hash :: String, length :: Int }

-- | Simple hash function (for demonstration - not cryptographically secure!)
simpleHash :: String -> Int
simpleHash str = do
  let chars = SCU.toCharArray str
  foldl (\acc _ -> (acc * 31 + String.length str) `mod` 1000000007) 0 chars

-- | CPU-intensive hash calculation with multiple iterations
computeHash :: String -> Int -> String
computeHash text iterations = do
  let
    go 0 current = current
    go n current = do
      let hashed = show (simpleHash current) <> current
      go (n - 1) hashed
  go iterations text

-- | Worker main function
-- | This receives inputs and sends back outputs
worker :: WB.WorkerContext Unit HashInput HashOutput -> Effect Unit
worker ctx = ctx.receive \{ text, iterations } -> do
  let hash = computeHash text iterations
  ctx.reply { hash, length: String.length hash }

-- | Entry point for the worker
main :: Effect Unit
main = WB.makeAsMain worker
