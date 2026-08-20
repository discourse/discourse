const REVOKE_AFTER = 20_000;

function parseFilename(contentDisposition) {
  if (!contentDisposition) {
    return null;
  }
  const utf8Match = contentDisposition.match(
    /filename\*\s*=\s*UTF-8''([^;]+)/i
  );
  if (utf8Match) {
    try {
      return decodeURIComponent(utf8Match[1].trim().replace(/^"|"$/g, ""));
    } catch {
      // fall through to ascii match
    }
  }
  const asciiMatch = contentDisposition.match(/filename\s*=\s*"?([^";]+)"?/i);
  return asciiMatch ? asciiMatch[1].trim() : null;
}

// Triggers a browser download of the given Blob via a hidden `<a download>`.
// Preferable to a plain `<a href target=_blank>` navigation for large binaries
// in iOS PWA and embedded WebView contexts, where the new-tab navigation
// either strands the user in a standalone window or renders the binary as
// text.
export function triggerBlobDownload(
  blob,
  { fallbackFilename, contentDisposition } = {}
) {
  const objectUrl = URL.createObjectURL(blob);
  const filename = parseFilename(contentDisposition) ?? fallbackFilename;
  const a = document.createElement("a");
  a.href = objectUrl;
  if (filename) {
    a.download = filename;
  }
  a.rel = "noopener";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(objectUrl), REVOKE_AFTER);
}

// Fetches `url` and triggers a browser download of the response body.
export default async function downloadBlob(
  url,
  { fallbackFilename, fetchOptions } = {}
) {
  const response = await fetch(url, {
    credentials: "same-origin",
    ...fetchOptions,
  });
  if (!response.ok) {
    throw new Error(`Download failed: ${response.status}`);
  }
  triggerBlobDownload(await response.blob(), {
    fallbackFilename,
    contentDisposition: response.headers.get("Content-Disposition"),
  });
}
