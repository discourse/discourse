/** The rendered onebox element of each url that loaded, keyed by normalized url. */
export let localCache: Record<string, Element> = {};

/** The normalized urls whose onebox request failed. */
export let failedCache: Record<string, boolean> = {};

// Sometimes jQuery will return URLs with trailing slashes when the
// `href` didn't have them.
export function resetLocalCache() {
  localCache = {};
}

export function resetFailedCache() {
  failedCache = {};
}

export function setLocalCache(key: string, value: Element) {
  localCache[key] = value;
}

export function setFailedCache(key: string, value: boolean) {
  failedCache[key] = value;
}

export function normalize(url: string): string {
  return url.replace(/\/$/, "");
}

/**
 * Looks up the markup of a onebox that already loaded.
 *
 * @param url - The url of the onebox.
 * @returns The onebox's HTML, or `undefined` when it isn't cached.
 */
export function lookupCache(url: string): string | undefined {
  return localCache[normalize(url)]?.outerHTML;
}
