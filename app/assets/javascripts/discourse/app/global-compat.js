import "discourse/lib/load-moment";
import jQuery from "jquery";
import virtualDom from "virtual-dom";
import widgetHelpers from "discourse-widget-hbs/helpers";

window.__widget_helpers = widgetHelpers;

// TODO: Eliminate this global
window.virtualDom = virtualDom;

if (!window.$) {
  window.$ = window.jQuery = jQuery;
}
