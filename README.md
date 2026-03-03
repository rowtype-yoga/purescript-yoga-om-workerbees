# purescript-yoga-om-workerbees

Multi-threaded computation for the Om effect monad using Node.js worker threads.

This library provides a clean, type-safe interface for running CPU-bound computations across multiple worker threads, with support for shared memory primitives and atomic operations.

## Features

- **Worker Pool Management**: Create and manage pools of worker threads
- **Shared Memory Primitives**:
  - `SharedInt`: Atomic Int32 reference with compare-and-swap
  - `SharedState`: JSON-serialized state with spinlock synchronization
  - `SharedMap`: Concurrent hash map with striped locks
- **Type-Safe**: Full PureScript type safety for worker communication
- **Om Integration**: Seamless integration with the Om effect monad
- **Automatic Work Distribution**: Distribute tasks across available workers

## Installation

```bash
spago install yoga-om-workerbees
```

**Dependencies:**
- `purescript-yoga-om` - The Om effect monad
- `purescript-node-workerbees` - Low-level worker thread bindings
- `purescript-yoga-json` - JSON serialization

## Quick Start

### 1. Create a Worker Module

```purescript
module MyWorker where

import Prelude
import Node.WorkerBees as WB

-- Worker function: Int -> Int
fibWorker :: Int -> Int
fibWorker n
  | n <= 1 = n
  | otherwise = fibWorker (n - 1) + fibWorker (n - 2)

-- Export as worker main
main :: Effect Unit
main = WB.makeAsMain fibWorker
```

### 2. Bundle the Worker

```bash
spago bundle \
  --module MyWorker \
  --outfile dist/workers/MyWorker.js \
  --platform node
```

### 3. Use the Worker Pool

```purescript
module Main where

import Prelude
import Effect.Aff (launchAff_)
import Yoga.Om.WorkerBees (makePool, distributeWork, terminatePool)

main :: Effect Unit
main = launchAff_ do
  -- Create worker pool
  pool <- makePool
    { workerPath: "./dist/workers/MyWorker.js"
    , poolSize: 4
    }

  -- Distribute work
  let inputs = [35, 36, 37, 38]
  results <- distributeWork pool inputs

  -- Clean up
  terminatePool pool
```

## Shared Memory

### SharedInt (Atomic Counter)

```purescript
import Yoga.Om.WorkerBees.SharedInt as SharedInt

-- Create atomic counter
counter <- SharedInt.new 0 # liftEffect

-- Atomic operations
SharedInt.add counter 1 # liftEffect
SharedInt.sub counter 1 # liftEffect
value <- SharedInt.read counter # liftEffect

-- Compare-and-swap
success <- SharedInt.compareAndSwap counter 0 42 # liftEffect

-- Atomic modify
SharedInt.modify counter (_ + 1) # liftEffect
```

### SharedState (JSON State)

```purescript
import Yoga.Om.WorkerBees.SharedState as SharedState

type AppState = { counter :: Int, message :: String }

-- Create shared state (1KB buffer)
state <- SharedState.new 1024 { counter: 0, message: "Hello" } # liftEffect

-- Read/write
current <- SharedState.read state # liftEffect
SharedState.write state { counter: 1, message: "Updated" } # liftEffect

-- Atomic modify
SharedState.modify state (\s -> s { counter = s.counter + 1 }) # liftEffect
```

### SharedMap (Concurrent Hash Map)

```purescript
import Yoga.Om.WorkerBees.SharedMap as SharedMap

-- Create map (16 stripes, 4KB per entry)
map <- SharedMap.new 16 4096 # liftEffect

-- Insert/lookup/delete
SharedMap.insert map "key" { value: 42 } # liftEffect
maybeValue <- SharedMap.lookup map "key" # liftEffect
SharedMap.delete map "key" # liftEffect

-- Atomic modify
SharedMap.modify map "key" (\v -> v { value = v.value + 1 }) # liftEffect
```

## Examples

Run the console examples:

```bash
# Install dependencies
bun install

# Fibonacci calculation with worker pool
bun run example:fibonacci

# Shared atomic counter
bun run example:counter

# Shared JSON state
bun run example:state

# Concurrent hash map
bun run example:map
```

See the `examples/` directory for full source code.

## When to Use WorkerBees

**Use WorkerBees for:**
- CPU-bound computations (cryptography, image processing, parsing)
- Parallel processing of large datasets
- Tasks that would block the event loop

**Don't use WorkerBees for:**
- I/O operations (use `Aff` instead - Node.js already handles I/O concurrency)
- Simple computations (overhead of worker communication isn't worth it)
- Shared state when Aff + `Ref` would suffice

## Architecture

- **WorkerPool**: Manages a pool of worker threads
- **Sendable**: Type-safe serialization for worker communication
- **SharedArrayBuffer**: Native shared memory between threads
- **Atomics**: Low-level atomic operations (load, store, compareExchange)
- **SharedInt/SharedState/SharedMap**: High-level shared memory abstractions

## Performance Tips

1. **Pool Size**: Default is 4 workers. Adjust based on CPU cores and workload:
   ```purescript
   makePool { workerPath, poolSize: 8 }
   ```

2. **Batch Work**: Distribute many small tasks rather than few large ones for better load balancing

3. **Shared Memory**: Use `makePoolWithData` to share memory instead of copying data:
   ```purescript
   counter <- SharedInt.new 0 # liftEffect
   pool <- makePoolWithData (SharedInt.toSendable counter) config
   ```

4. **Worker Bundling**: Always bundle workers with `--platform node` for optimal performance

## License

MIT

