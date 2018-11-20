import PreloadStore from "preload-store";

let _customizations = {};

export function getCustomHTML(key) {
  const c = _customizations[key];
  if (c) {
    return new Handlebars.SafeString(c);
  }

  const html = PreloadStore.get("customHTML");
  if (html && html[key] && html[key].length) {
    return new Handlebars.SafeString(html[key]);
  }
}

export function clearHTMLCache() {
  _customizations = {};
}

// Set a fragment of HTML by key. It can then be looked up with `getCustomHTML(key)`.
export function setCustomHTML(key, html) {
  _customizations[key] = html;
}
