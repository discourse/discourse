(function () {
  if (window.unsupportedBrowser) {
    throw "Unsupported browser detected";
  }

  // TODO: Remove this and have resolver find the templates
  const discoursePrefix = "discourse/templates/";
  const adminPrefix = "admin/templates/";
  const wizardPrefix = "wizard/templates/";
  const discoursePrefixLength = discoursePrefix.length;

  const pluginRegex = /^discourse\/plugins\/([^\/]+)\//;

  Object.keys(requirejs.entries).forEach(function (key) {
    let templateKey;
    let pluginName;
    if (key.startsWith(discoursePrefix)) {
      templateKey = key.slice(discoursePrefixLength);
    } else if (key.startsWith(adminPrefix) || key.startsWith(wizardPrefix)) {
      templateKey = key;
    } else if (
      (pluginName = key.match(pluginRegex)?.[1]) &&
      key.includes("/templates/") &&
      require(key).default.__id // really is a template
    ) {
      // This logic mimics the old sprockets compilation system which used to
      // output templates directly to `Ember.TEMPLATES` with this naming logic
      templateKey = key.slice(`discourse/plugins/${pluginName}/`.length);
      templateKey = templateKey.replace("discourse/templates/", "");
      templateKey = `javascripts/${templateKey}`;
    }

    if (templateKey) {
      Ember.TEMPLATES[templateKey] = require(key).default;
    }
  });

  window.__widget_helpers = require("discourse-widget-hbs/helpers").default;

  // TODO: Eliminate this global
  window.virtualDom = require("virtual-dom");

  let element = document.querySelector(
    `meta[name="discourse/config/environment"]`
  );
  const config = JSON.parse(
    decodeURIComponent(element.getAttribute("content"))
  );
  const event = new CustomEvent("discourse-booted", { detail: config });
  document.dispatchEvent(event);
})();
