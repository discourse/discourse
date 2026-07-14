// Number of ms to keep the object URL alive after the click so the browser has
// time to start the download before it is revoked.
const REVOKE_AFTER_MS = 30_000;

/**
 * Triggers a client-side download of a JSON document, without navigating away
 * (so an in-session editor isn't torn down). `content` MUST already be a
 * serialized JSON string — it is wrapped in a Blob verbatim and never
 * re-stringified.
 *
 * @param {string} filename - The suggested download filename (e.g. `block_layouts/x.json`).
 * @param {string} content - The already-serialized JSON string to download.
 * @returns {void}
 */
export function downloadJson(filename, content) {
  const blob = new Blob([content], { type: "application/json" });
  const url = window.URL.createObjectURL(blob);

  const anchor = document.createElement("a");
  anchor.style.display = "none";
  anchor.href = url;
  // A path-like filename is fine: browsers use the basename for the download.
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();

  setTimeout(() => window.URL.revokeObjectURL(url), REVOKE_AFTER_MS);
}
