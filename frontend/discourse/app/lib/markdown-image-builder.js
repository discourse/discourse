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
