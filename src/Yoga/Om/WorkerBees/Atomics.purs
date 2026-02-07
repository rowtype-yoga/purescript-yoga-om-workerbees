module Yoga.Om.WorkerBees.Atomics
  ( load
  , store
  , add
  , sub
  , exchange
  , compareExchange
  , notify
  ) where

import Data.ArrayBuffer.Types (Int32Array)
import Effect (Effect)
import Effect.Uncurried (EffectFn2, EffectFn3, EffectFn4, runEffectFn2, runEffectFn3, runEffectFn4)

foreign import loadImpl :: EffectFn2 Int32Array Int Int

load :: Int32Array -> Int -> Effect Int
load = runEffectFn2 loadImpl

foreign import storeImpl :: EffectFn3 Int32Array Int Int Int

store :: Int32Array -> Int -> Int -> Effect Int
store = runEffectFn3 storeImpl

foreign import addImpl :: EffectFn3 Int32Array Int Int Int

add :: Int32Array -> Int -> Int -> Effect Int
add = runEffectFn3 addImpl

foreign import subImpl :: EffectFn3 Int32Array Int Int Int

sub :: Int32Array -> Int -> Int -> Effect Int
sub = runEffectFn3 subImpl

foreign import exchangeImpl :: EffectFn3 Int32Array Int Int Int

exchange :: Int32Array -> Int -> Int -> Effect Int
exchange = runEffectFn3 exchangeImpl

foreign import compareExchangeImpl :: EffectFn4 Int32Array Int Int Int Int

compareExchange :: Int32Array -> Int -> Int -> Int -> Effect Int
compareExchange = runEffectFn4 compareExchangeImpl

foreign import notifyImpl :: EffectFn3 Int32Array Int Int Int

notify :: Int32Array -> Int -> Int -> Effect Int
notify = runEffectFn3 notifyImpl
