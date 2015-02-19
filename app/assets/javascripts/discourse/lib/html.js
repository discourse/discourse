var customizations = {};

Discourse.HTML = {

  /**
    Return a custom fragment of HTML by key. It can be registered via a plugin
    using `setCustomHTML(key, html)`. This is used by a handlebars helper to find
    the HTML content it wants. It will also check the `PreloadStore` for any server
    side preloaded HTML.
  **/
  getCustomHTML: function(key) {
    var c = customizations[key];
    if (c) {
      return new Handlebars.SafeString(c);
    }

    var html = PreloadStore.get("customHTML");
    if (html && html[key] && html[key].length) {
      return new Handlebars.SafeString(html[key]);
    }
  },

  // Set a fragment of HTML by key. It can then be looked up with `getCustomHTML(key)`.
  setCustomHTML: function(key, html) {
    customizations[key] = html;
  }

};
