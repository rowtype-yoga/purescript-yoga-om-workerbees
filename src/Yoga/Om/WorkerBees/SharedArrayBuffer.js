export const newImpl = (byteLength) => {
  return new SharedArrayBuffer(byteLength);
};

export const byteLengthImpl = (sab) => sab.byteLength;

export const toInt32ArrayImpl = (sab) => {
  return new Int32Array(sab);
};

export const toInt32ArraySliceImpl = (sab, byteOffset, length) => {
  return new Int32Array(sab, byteOffset, length);
};
