import widgetHelpers from "discourse-widget-hbs/helpers";
import virtualDom from "virtual-dom";

window.__widget_helpers = widgetHelpers;

// TODO: Eliminate this global
window.virtualDom = virtualDom;
