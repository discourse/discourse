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
    return htmlSafe(html[key]);
  }
}

export function clearHTMLCache() {
  _customizations = {};
}

// Set a fragment of HTML by key. It can then be looked up with `getCustomHTML(key)`.
export function setCustomHTML(key, html) {
  _customizations[key] = html;
}
