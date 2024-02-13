import { htmlSafe } from "@ember/template";
import PreloadStore from "discourse/lib/preload-store";

let _customizations = {};

export function getCustomHTML(key) {
  const c = _customizations[key];
  if (c) {
    return htmlSafe(c);
  }

  const html = PreloadStore.get("customHTML");
  if (html && html[key] && html[key].length) {
    let thisHtml = html[key];
    // TODO: Is this needed? Do theme devs put script tags in these sections?
    // const cspNonce = document.querySelector(
    //   "script[data-entrypoint=discourse]"
    // ).nonce;
    // thisHtml = html[key].replaceAll(
    //   "__CSP__NONCE__PLACEHOLDER__f72bff1b1768168a34ee092ce759f192__",
    //   `nonce="${cspNonce}"`
    // );
    return htmlSafe(thisHtml);
  }
}

export function clearHTMLCache() {
  _customizations = {};
}

// Set a fragment of HTML by key. It can then be looked up with `getCustomHTML(key)`.
export function setCustomHTML(key, html) {
  _customizations[key] = html;
}
