const MAX_FILENAME_LENGTH = 180;
const MAX_KEPT_EXTENSION_LENGTH = 32;

// Treat remote metadata as untrusted, including path separators, control
// characters and bidi overrides that can disguise an executable extension.
// Truncation keeps the final extension so it can't expose an inner one.
export function safeTransferFilename(name) {
  let safe = String(name || "")
    .replace(/[\\/<>:"|?*\u0000-\u001f\u007f-\u009f‪-‮⁦-⁩]/g, "_")
    .replace(/^[.\s]+|[.\s]+$/g, "");
  if (safe.length > MAX_FILENAME_LENGTH) {
    const dot = safe.lastIndexOf(".");
    const extension =
      dot > 0 && safe.length - dot <= MAX_KEPT_EXTENSION_LENGTH
        ? safe.slice(dot)
        : "";
    safe = safe.slice(0, MAX_FILENAME_LENGTH - extension.length) + extension;
  }
  return safe || "download";
}
