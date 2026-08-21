import { capabilities } from "discourse/services/capabilities";

// Reports how the current runtime handles server-generated attachment
// downloads (responses with `Content-Disposition: attachment`).
//
//   "native" — a plain <a href> triggers a proper download: the browser
//              streams to disk, uses its own header parser to pick the
//              filename, and shows its native progress UI. This is the case
//              for desktop and mobile browsers.
//   "blob"   — a new-tab navigation to an attachment strands the user in a
//              standalone window (iOS PWA). Callers must fetch the response
//              and trigger a client-side blob download instead.
//   "bridge" — Discourse Hub receives a bounded Blob over its web/native
//              bridge, writes a temporary file, and opens native save/share UI.
export function attachmentDownloadStrategy() {
  if (capabilities.isAppWebview) {
    return "bridge";
  }
  if (capabilities.isPwa) {
    return "blob";
  }
  return "native";
}
