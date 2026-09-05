// MiniRacer (embedded V8) does not provide the browser globals that bundled
// dependencies (e.g. entities v8, used by markdown-it v15) assume exist. The
// `base-64` package (MIT) implements the WHATWG atob/btoa algorithms with no
// runtime dependencies, so it works in non-browser environments.
import base64 from "base-64";

if (typeof atob === "undefined") {
  globalThis.atob = (data) => base64.decode(data);
}

if (typeof btoa === "undefined") {
  globalThis.btoa = (data) => base64.encode(data);
}
