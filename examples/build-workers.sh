#!/usr/bin/env bash

# Build script for worker modules
# This bundles the workers into standalone JavaScript files

set -e

# Ensure purs is in PATH
export PATH="./node_modules/.bin:$PATH"

echo "Building workers..."

# Build all PureScript modules first
echo "  Compiling PureScript..."
spago build

# Bundle Fibonacci worker
echo "  Bundling FibonacciWorker..."
spago bundle \
  --module Examples.Workers.FibonacciWorker \
  --outfile dist/workers/FibonacciWorker.js \
  --platform node

# Bundle Hash worker
echo "  Bundling HashWorker..."
spago bundle \
  --module Examples.Workers.HashWorker \
  --outfile dist/workers/HashWorker.js \
  --platform node

# Bundle Counter worker (shared memory example)
echo "  Bundling CounterWorker..."
spago bundle \
  --module Examples.Workers.CounterWorker \
  --outfile dist/workers/CounterWorker.js \
  --platform node

echo "Workers built successfully!"
