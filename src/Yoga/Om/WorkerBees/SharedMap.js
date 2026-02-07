const encoder = new TextEncoder();
const decoder = new TextDecoder();

// DJB2 hash: string -> segment index
export const hashKeyImpl = (key, numSegments) => {
  let hash = 5381;
  for (let i = 0; i < key.length; i++) {
    hash = ((hash << 5) + hash + key.charCodeAt(i)) | 0;
  }
  return (hash >>> 0) % numSegments;
};

// Write JSON string at a byte offset in the SharedArrayBuffer
// Returns the byte length written
export const writeSegmentDataImpl = (sab, byteOffset, json) => {
  const bytes = encoder.encode(json);
  const target = new Uint8Array(sab, byteOffset, bytes.byteLength);
  target.set(bytes);
  return bytes.byteLength;
};

// Read JSON string from a byte offset in the SharedArrayBuffer
export const readSegmentDataImpl = (sab, byteOffset, len) => {
  const source = new Uint8Array(sab, byteOffset, len);
  return decoder.decode(source);
};

// Read an Int32 at a byte offset (for reading header in fromSendable)
export const readInt32Impl = (sab, byteOffset) => {
  const view = new Int32Array(sab, byteOffset, 1);
  return view[0];
};

// Get UTF-8 byte length of a string (for overflow check before writing)
export const stringByteLengthImpl = (str) => {
  return encoder.encode(str).byteLength;
};
