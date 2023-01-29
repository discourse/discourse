(function () {
  if (window.unsupportedBrowser) {
    throw "Unsupported browser detected";
  }

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
