# WorkerBees Quick Start Guide

This guide will walk you through creating your first multi-threaded PureScript application using WorkerBees.

## Step 1: Install Dependencies

```bash
spago install yoga-om-workerbees
```

## Step 2: Create a Worker Module

Create `src/Workers/MyWorker.purs`:

```purescript
module Workers.MyWorker where

import Prelude
import Effect (Effect)
import Node.WorkerBees as WB

-- This is the function that will run in worker threads
-- For this example, we'll compute the square of a number
squareWorker :: Int -> Int
squareWorker n = n * n

-- Export as worker main - this is required!
main :: Effect Unit
main = WB.makeAsMain squareWorker
```

**Important:** The worker module must export a `main` function that calls `WB.makeAsMain`.

## Step 3: Create the Main Application

Create `src/Main.purs`:

```purescript
module Main where

import Prelude

import Data.Array as Array
import Data.Traversable (for_)
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class.Console (log)
import Yoga.Om.WorkerBees (makePool, distributeWork, terminatePool)

main :: Effect Unit
main = launchAff_ do
  log "Starting worker pool..."

  -- Step 1: Create worker pool
  pool <- makePool
    { workerPath: "./dist/workers/MyWorker.js"
    , poolSize: 4  -- Use 4 worker threads
    }

  -- Step 2: Prepare input data
  let inputs = Array.range 1 10  -- [1, 2, 3, ..., 10]

  log $ "Computing squares of: " <> show inputs

  -- Step 3: Distribute work across workers
  results <- distributeWork pool inputs

  -- Step 4: Print results
  log "Results:"
  for_ (Array.zip inputs results) \(input, result) -> do
    log $ "  " <> show input <> "² = " <> show result

  -- Step 5: Clean up
  log "Terminating pool..."
  terminatePool pool

  log "Done!"
```

## Step 4: Bundle the Worker

Create a build script `scripts/build-workers.sh`:

```bash
#!/usr/bin/env bash
set -e

echo "Building PureScript..."
spago build

echo "Bundling worker..."
spago bundle \
  --module Workers.MyWorker \
  --outfile dist/workers/MyWorker.js \
  --platform node

echo "Worker bundled successfully!"
```

Make it executable:

```bash
chmod +x scripts/build-workers.sh
```

## Step 5: Update package.json

Add scripts to your `package.json`:

```json
{
  "scripts": {
    "build": "spago build",
    "build:workers": "bash scripts/build-workers.sh",
    "start": "bun run build:workers && spago run"
  }
}
```

## Step 6: Run Your Application

```bash
bun run start
```

You should see output like:

```
Starting worker pool...
Computing squares of: [1,2,3,4,5,6,7,8,9,10]
Results:
  1² = 1
  2² = 4
  3² = 9
  4² = 16
  5² = 25
  6² = 36
  7² = 49
  8² = 64
  9² = 81
  10² = 100
Terminating pool...
Done!
```

## Understanding What Happened

1. **Worker Creation**: `makePool` created 4 worker threads, each running `dist/workers/MyWorker.js`

2. **Work Distribution**: `distributeWork` automatically:
   - Split the 10 inputs across 4 workers
   - Sent tasks to available workers
   - Collected results in order

3. **Parallel Execution**: Workers computed squares in parallel (faster than sequential for real CPU-bound work)

4. **Cleanup**: `terminatePool` terminated all workers and freed resources

## Next Steps

### Add Shared Memory

Create a shared counter that workers can increment:

```purescript
import Yoga.Om.WorkerBees (makePoolWithData)
import Yoga.Om.WorkerBees.SharedInt as SharedInt

main :: Effect Unit
main = launchAff_ do
  -- Create shared counter
  counter <- SharedInt.new 0 # liftEffect

  -- Create pool with shared data
  pool <- makePoolWithData (SharedInt.toSendable counter)
    { workerPath: "./dist/workers/CounterWorker.js"
    , poolSize: 4
    }

  -- Workers can now access the counter via context.workerData
  -- ...

  finalValue <- SharedInt.read counter # liftEffect
  log $ "Final counter value: " <> show finalValue
```

Worker side:

```purescript
module Workers.CounterWorker where

import Prelude
import Effect (Effect)
import Node.WorkerBees as WB
import Yoga.Om.WorkerBees.SharedInt as SharedInt

counterWorker :: WB.SendWrapper SharedInt.SharedInt -> Int -> Effect Int
counterWorker sendable _ = do
  counter <- SharedInt.fromSendable sendable
  SharedInt.add counter 1
  SharedInt.read counter

main :: Effect Unit
main = WB.makeAsMain counterWorker
```

### Use More Complex Data Types

Workers can handle any `Sendable` type (JSON-serializable):

```purescript
type Task =
  { id :: Int
  , operation :: String
  , value :: Number
  }

type Result =
  { taskId :: Int
  , result :: Number
  , processingTime :: Number
  }

-- Worker function
processTask :: Task -> Effect Result
processTask task = do
  -- ... process task ...
  pure { taskId: task.id, result: 42.0, processingTime: 10.0 }
```

### Error Handling

Add error handling to workers:

```purescript
import Data.Either (Either(..))
import Control.Monad.Error.Class (try)

safeWorker :: Int -> Effect (Either String Int)
safeWorker n = try do
  when (n < 0) $ throw "Negative numbers not allowed"
  pure (n * n)
```

## Common Pitfalls

1. **Forgetting to Bundle**: Workers must be bundled with `spago bundle --platform node`

2. **Wrong Worker Path**: Path must be relative to where you run the app (usually `./dist/workers/...`)

3. **Not Calling `makeAsMain`**: Worker `main` function must call `WB.makeAsMain yourFunction`

4. **Using for I/O**: WorkerBees is for CPU-bound tasks. Use `Aff` for I/O operations.

5. **Forgetting `terminatePool`**: Always clean up workers to free resources

## Tips for Production

1. **Adjust Pool Size**: Match CPU cores for CPU-bound work:
   ```purescript
   poolSize: 8  -- For 8-core machine
   ```

2. **Batch Tasks**: Send many small tasks instead of few large ones for better load balancing

3. **Monitor Performance**: Add timing to see if workers actually help:
   ```purescript
   start <- nowDateTime # liftEffect
   results <- distributeWork pool inputs
   end <- nowDateTime # liftEffect
   let duration = diff end start
   log $ "Completed in: " <> show duration
   ```

4. **Graceful Shutdown**: Always terminate pools on app shutdown to avoid zombie processes

## More Examples

Check the `examples/` directory for more advanced usage:
- `FibonacciDemo.purs` - CPU-bound computation
- `SharedCounterDemo.purs` - Atomic operations
- `SharedStateDemo.purs` - JSON state management
- `SharedMapDemo.purs` - Concurrent hash map

Happy parallel computing! 🚀
