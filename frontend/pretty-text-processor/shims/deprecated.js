// Server-side stand-in for discourse/lib/deprecated; the real one pulls a
// browser-only dependency chain. Reproduces its console.warn message format.
export default function deprecated(msg, options = {}) {
  const { id, since, url } = options;
  const parts = ["DEPRECATION NOTICE:", msg];
  if (since) {
    parts.push(`[deprecated since Discourse ${since}]`);
  }
  if (id) {
    parts.push(`[deprecation id: ${id}]`);
  }
  if (url) {
    parts.push(`[info: ${url}]`);
  }
  // eslint-disable-next-line no-console
  console.warn(parts.join(" "));
}
export function registerDeprecationHandler() {}
export function withSilencedDeprecations(_ids, callback) {
  return callback();
}
export async function withSilencedDeprecationsAsync(_ids, callback) {
  return callback();
}
export function isDeprecationSilenced() {
  return false;
}
