// Treat remote metadata as untrusted, including path separators, control
// characters and bidi overrides that can disguise an executable extension.
export function safeTransferFilename(name) {
  const safe = String(name || "")
    .replace(
      /[\\/<>:"|?*\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/g,
      "_"
    )
    .replace(/^[.\s]+|[.\s]+$/g, "")
    .slice(0, 180);
  return safe || "download";
}
