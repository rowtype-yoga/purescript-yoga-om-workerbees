module Yoga.Om.WorkerBees.SharedArrayBuffer
  ( SharedArrayBuffer
  , new
  , byteLength
  , toInt32Array
  , toInt32ArraySlice
  ) where

import Data.ArrayBuffer.Types (Int32Array)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn3, runEffectFn1, runEffectFn3)

foreign import data SharedArrayBuffer :: Type

foreign import newImpl :: EffectFn1 Int SharedArrayBuffer

new :: Int -> Effect SharedArrayBuffer
new = runEffectFn1 newImpl

foreign import byteLengthImpl :: SharedArrayBuffer -> Int

byteLength :: SharedArrayBuffer -> Int
byteLength = byteLengthImpl

foreign import toInt32ArrayImpl :: EffectFn1 SharedArrayBuffer Int32Array

toInt32Array :: SharedArrayBuffer -> Effect Int32Array
toInt32Array = runEffectFn1 toInt32ArrayImpl

foreign import toInt32ArraySliceImpl :: EffectFn3 SharedArrayBuffer Int Int Int32Array

toInt32ArraySlice :: SharedArrayBuffer -> Int -> Int -> Effect Int32Array
toInt32ArraySlice = runEffectFn3 toInt32ArraySliceImpl
