# WorkerBees Examples

This directory contains console-based examples demonstrating the WorkerBees library functionality.

## Running Examples

All examples require building the workers first:

```bash
bun run build:workers
```

Then run any example:

```bash
bun run example:fibonacci    # Fibonacci calculation
bun run example:counter      # Shared atomic counter
bun run example:state        # Shared JSON state
bun run example:map          # Concurrent hash map
```

## Example Descriptions

### FibonacciDemo

**File:** `FibonacciDemo.purs`
**Worker:** `Workers/FibonacciWorker.purs`

Demonstrates basic worker pool usage with CPU-bound computation:
- Creates a pool of 4 workers
- Distributes Fibonacci calculations across workers
- Collects and displays results
- Shows proper cleanup

**Key concepts:**
- Worker pool creation
- Work distribution
- Result collection

### SharedCounterDemo

**File:** `SharedCounterDemo.purs`
**Worker:** `Workers/CounterWorker.purs`

Demonstrates `SharedInt` (atomic Int32 reference):
- Creates a shared atomic counter
- Passes counter to workers via `workerData`
- 100 concurrent increment operations
- Shows final counter value

**Key concepts:**
- Shared memory creation
- Atomic operations
- Thread-safe increments
- `makePoolWithData` for sharing state

### SharedStateDemo

**File:** `SharedStateDemo.purs`

Demonstrates `SharedState` (JSON-serialized state with spinlock):
- Creates shared state with record type
- Read and write operations
- Atomic modify operations
- Spinlock synchronization

**Key concepts:**
- JSON serialization
- Atomic modify with CAS loop
- Spinlock-based synchronization
- Buffer size management

### SharedMapDemo

**File:** `SharedMapDemo.purs`

Demonstrates `SharedMap` (concurrent hash map):
- Creates striped concurrent map
- Insert, lookup, modify, delete operations
- Shows concurrent access patterns
- Demonstrates striped lock benefits

**Key concepts:**
- Concurrent hash map
- Striped locking
- Key-value operations
- Lock-free reads

## Worker Implementations

### FibonacciWorker

Classic recursive Fibonacci - CPU-bound computation perfect for demonstrating worker benefits.

```purescript
fibWorker :: Int -> Int
fibWorker n
  | n <= 1 = n
  | otherwise = fibWorker (n - 1) + fibWorker (n - 2)
```

### CounterWorker

Increments a shared counter and returns the new value:

```purescript
counterWorker :: SendWrapper SharedInt -> Int -> Effect Int
counterWorker sendable _ = do
  counter <- SharedInt.fromSendable sendable
  SharedInt.add counter 1
  SharedInt.read counter
```

### HashWorker

Processes text (calculates hash codes) - demonstrates string processing workload:

```purescript
hashWorker :: String -> Effect Int
hashWorker text = pure $ hashString text
```

## Building Workers Manually

The `build-workers.sh` script bundles all workers, but you can also build individually:

```bash
spago bundle \
  --module Examples.Workers.FibonacciWorker \
  --outfile dist/workers/FibonacciWorker.js \
  --platform node
```

**Important:** Always use `--platform node` for worker bundles!

## Tips for Writing Your Own Examples

1. **Worker Entry Point**: Always use `WB.makeAsMain yourFunction` as the worker's `main`

2. **Bundle Before Running**: Workers must be bundled to `dist/workers/*.js` before use

3. **Shared Memory**: Use `SendWrapper` types for passing shared memory to workers:
   ```purescript
   counter <- SharedInt.new 0 # liftEffect
   pool <- makePoolWithData (SharedInt.toSendable counter) config
   ```

4. **Error Handling**: Workers should handle errors gracefully - unhandled errors will crash the worker

5. **Cleanup**: Always call `terminatePool` when done to free resources

## Performance Notes

- **Pool Size**: Examples use 4 workers by default. Adjust based on your CPU cores.
- **Batch Size**: `distributeWork` automatically batches tasks across available workers.
- **Shared Memory**: Faster than message passing when state is frequently accessed.
- **Overhead**: Worker communication has overhead - only use for CPU-bound tasks that take >10ms.

## Further Reading

- See the main `README.md` for API documentation
- See `QUICKSTART.md` for a step-by-step tutorial
- Check worker source code in `Workers/` for implementation details
