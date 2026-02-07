module Examples.Workers.CounterWorker where

import Prelude

import Effect (Effect)
import Node.WorkerBees (SendWrapper)
import Node.WorkerBees as WB
import Yoga.Om.WorkerBees.SharedInt as SharedInt

type CounterInput = { n :: Int }
type CounterOutput = { result :: Int, count :: Int }

fibonacci :: Int -> Int
fibonacci n
  | n <= 1 = n
  | otherwise = fibonacci (n - 1) + fibonacci (n - 2)

worker :: WB.WorkerContext (SendWrapper SharedInt.SharedInt) CounterInput CounterOutput -> Effect Unit
worker ctx = do
  let counter = SharedInt.fromSendable ctx.workerData
  ctx.receive \{ n } -> do
    let result = fibonacci n
    _ <- SharedInt.add counter 1
    count <- SharedInt.read counter
    ctx.reply { result, count }

main :: Effect Unit
main = WB.makeAsMain worker
