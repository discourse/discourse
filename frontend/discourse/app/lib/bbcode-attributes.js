/**
 * Encodes a string value for safe use in BBCode attributes.
 *
 * Converts strings to base64url format, replacing characters that have
 * special meaning in BBCode ('+', '/', '=') with URL-safe alternatives
 * ('-', '_', '~').
 *
 * @param {string} value - The string value to encode
 * @returns {string} The base64url-encoded string
 */
export function bbcodeAttributeEncode(value) {
  const utf8Bytes = new TextEncoder().encode(value);
  const binaryString = Array.from(utf8Bytes, (byte) =>
    String.fromCharCode(byte)
  ).join("");
  const base64 = btoa(binaryString);

  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "~");
}

/**
 * Decodes a base64url-encoded string from a BBCode attribute.
 *
 * Reverses the encoding performed by bbcodeAttributeEncode.
 *
 * @param {string} encodedValue - The base64url-encoded string to decode
 * @returns {string} The decoded UTF-8 string
 */
export function bbcodeAttributeDecode(encodedValue) {
  const base64 = encodedValue
    .replace(/-/g, "+")
    .replace(/_/g, "/")
    .replace(/~/g, "=");

  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }

  return new TextDecoder().decode(bytes);
}
