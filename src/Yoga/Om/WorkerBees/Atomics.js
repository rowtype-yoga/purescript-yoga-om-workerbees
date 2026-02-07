export const loadImpl = (arr, idx) => Atomics.load(arr, idx);

export const storeImpl = (arr, idx, val) => Atomics.store(arr, idx, val);

export const addImpl = (arr, idx, val) => Atomics.add(arr, idx, val);

export const subImpl = (arr, idx, val) => Atomics.sub(arr, idx, val);

export const exchangeImpl = (arr, idx, val) => Atomics.exchange(arr, idx, val);

export const compareExchangeImpl = (arr, idx, expected, replacement) =>
  Atomics.compareExchange(arr, idx, expected, replacement);

export const notifyImpl = (arr, idx, count) => Atomics.notify(arr, idx, count);
