export function sanitizeAlt(text, options = {}) {
  const fallback = options.fallback ?? "";

  if (!text) {
    return fallback;
  }

  const trimmed = text.trim();
  if (!trimmed) {
    return fallback;
  }

  return trimmed.replace(/\|/g, "&#124;").replace(/([\\\[\]])/g, "\\$1");
}

/**
 * Extracts the extension (without dot) from a URL or path.
 * Returns null when no extension is present.
 *
 * @param {string} url
 * @returns {string|null}
 */
export function extensionFromUrl(url) {
  if (!url) {
    return null;
  }

  const match = url.match(/\.([a-zA-Z0-9]+)(?:\?|$)/);
  return match ? match[1] : null;
}

export function buildImageMarkdown(imageData) {
  const {
    src,
    alt,
    width,
    height,
    title,
    escapeTablePipe = false,
    fallbackAlt,
  } = imageData;

  if (!src) {
    return "";
  }

  const altText = sanitizeAlt(alt, { fallback: fallbackAlt });
  const pipe = escapeTablePipe ? "\\|" : "|";
  const suffix = width && height ? `${pipe}${width}x${height}` : "";
  const titleSuffix = title ? ` "${title}"` : "";

  return `![${altText}${suffix}](${src}${titleSuffix})`;
}
