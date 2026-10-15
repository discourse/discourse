// @ts-check

const ALLOWED_SCHEMES = new Set(["http", "https", "mailto", "tel"]);

/**
 * Whether an href is safe to store and render. Rejects dangerous schemes
 * (`javascript:`, `data:`, etc.) and control characters. Permits relative
 * paths, fragment links, and the http/https/mailto/tel schemes.
 *
 * @param {unknown} href
 * @returns {boolean}
 */
export function isSafeHref(href) {
  if (typeof href !== "string" || href.length === 0) {
    return false;
  }

  // Reject control characters anywhere. Browsers strip some of these
  // (tab / newline / NUL) while resolving a URL, which could smuggle an
  // otherwise-blocked scheme past a naive check (e.g. `java\tscript:`).
  if (/[\x00-\x1F\x7F]/.test(href)) {
    return false;
  }

  // Browsers also strip leading/trailing spaces before resolving the
  // scheme, so e.g. `" javascript:alert(1)"` would execute. Run the
  // scheme checks against the trimmed value.
  const value = href.trim();
  if (value.length === 0) {
    return false;
  }
  if (value.startsWith("/") || value.startsWith("#") || value.startsWith("?")) {
    return true;
  }
  const match = value.match(/^([a-zA-Z][a-zA-Z0-9+.-]*):/);
  if (!match) {
    return true;
  }
  return ALLOWED_SCHEMES.has(match[1].toLowerCase());
}

/**
 * Coalesces an href to a render-safe value: returns the string unchanged when
 * {@link isSafeHref} approves it, otherwise `"#"`. Use this when binding a
 * value straight to an `href` attribute so an unsafe scheme can never reach
 * the DOM.
 *
 * @param {unknown} href
 * @returns {string}
 */
export function safeHref(href) {
  return isSafeHref(href) ? String(href) : "#";
}
