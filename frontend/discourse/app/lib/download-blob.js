import { capabilities } from "discourse/services/capabilities";

const REVOKE_AFTER = 20_000;
export const MAX_BRIDGED_DOWNLOAD_BYTES = 25 * 1024 * 1024;

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

function blobAsBase64(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () =>
      reject(reader.error ?? new Error("File read failed"));
    reader.onload = () => {
      const result = reader.result;
      const comma = typeof result === "string" ? result.indexOf(",") : -1;
      if (comma === -1) {
        reject(new Error("File encoding failed"));
      } else {
        resolve(result.slice(comma + 1));
      }
    };
    reader.readAsDataURL(blob);
  });
}

export async function bridgeBlobDownload(
  blob,
  { fallbackFilename, contentDisposition } = {}
) {
  if (blob.size > MAX_BRIDGED_DOWNLOAD_BYTES) {
    throw new Error("Download is too large for the in-app downloader");
  }

  const filename = parseFilename(contentDisposition) ?? fallbackFilename;
  if (!filename) {
    throw new Error("Download filename is missing");
  }

  const data = await blobAsBase64(blob);
  window.ReactNativeWebView.postMessage(
    JSON.stringify({
      type: "download",
      version: 1,
      encoding: "base64",
      filename,
      mimeType: blob.type || "application/octet-stream",
      byteLength: blob.size,
      data,
    })
  );
}

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

export async function deliverBlobDownload(blob, options = {}) {
  if (capabilities.isAppWebview) {
    await bridgeBlobDownload(blob, options);
  } else {
    triggerBlobDownload(blob, options);
  }
}

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
  await deliverBlobDownload(await response.blob(), {
    fallbackFilename,
    contentDisposition: response.headers.get("Content-Disposition"),
  });
}
