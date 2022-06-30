(function () {
  if (window.unsupportedBrowser) {
    throw "Unsupported browser detected";
  }

  // TODO: Remove this and have resolver find the templates
  const prefix = "discourse/templates/";
  const adminPrefix = "admin/templates/";
  const wizardPrefix = "wizard/templates/";
  let len = prefix.length;
  Object.keys(requirejs.entries).forEach(function (key) {
    if (key.startsWith(prefix)) {
      Ember.TEMPLATES[key.slice(len)] = require(key).default;
    } else if (key.startsWith(adminPrefix) || key.startsWith(wizardPrefix)) {
      Ember.TEMPLATES[key] = require(key).default;
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
