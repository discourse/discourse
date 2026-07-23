// Server-side stand-in for discourse/lib/deprecated. The real module pulls a
// source-identifier -> preload-store -> rsvp chain and reads `document`, none of
// which apply server-side. This reproduces its console.warn message format (the
// non-fatal path — server cook never raises on deprecation) and no-ops the rest.
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
