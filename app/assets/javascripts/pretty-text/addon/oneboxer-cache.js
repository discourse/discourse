export let localCache = {};
export let failedCache = {};

// Sometimes jQuery will return URLs with trailing slashes when the
// `href` didn't have them.
export function resetLocalCache() {
  localCache = {};
}

export function resetFailedCache() {
  failedCache = {};
}

export function setLocalCache(key, value) {
  localCache[key] = value;
}

export function setFailedCache(key, value) {
  failedCache[key] = value;
}

export function normalize(url) {
  return url.replace(/\/$/, "");
}

export function lookupCache(url) {
  const cached = localCache[normalize(url)];
  return cached && cached.prop("outerHTML");
}
