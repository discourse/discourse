import virtualDom from "@discourse/virtual-dom";
import widgetHelpers from "discourse-widget-hbs/helpers";

window.__widget_helpers = widgetHelpers;

// TODO: Eliminate this global
window.virtualDom = virtualDom;
