var _customizations = {};

/**
  Return a custom fragment of HTML by key. It can be registered via a plugin
  using `setCustomHTML(key, html)`. This is used by a handlebars helper to find
  the HTML content it wants. It will also check the `PreloadStore` for any server
  side preloaded HTML.
**/
export function getCustomHTML(key) {
  var c = _customizations[key];
  if (c) {
    return new Handlebars.SafeString(c);
  }

  var html = PreloadStore.get("customHTML");
  if (html && html[key] && html[key].length) {
    return new Handlebars.SafeString(html[key]);
  }
}

// Set a fragment of HTML by key. It can then be looked up with `getCustomHTML(key)`.
export function setCustomHTML(key, html) {
  _customizations[key] = html;
}

var HTML = {
  getCustomHTML: getCustomHTML,
  setCustomHTML: setCustomHTML
};

Discourse.HTML = HTML;
export default HTML;
