const encoder = new TextEncoder();
const decoder = new TextDecoder();

// Write a JSON string into the SharedArrayBuffer starting at byte offset 8
export const writeDataImpl = (sab, jsonStr) => {
  const bytes = encoder.encode(jsonStr);
  const target = new Uint8Array(sab, 8, bytes.byteLength);
  target.set(bytes);
  return bytes.byteLength;
};

// Read a JSON string from the SharedArrayBuffer starting at byte offset 8
export const readDataImpl = (sab, byteLength) => {
  const source = new Uint8Array(sab, 8, byteLength);
  return decoder.decode(source);
};
