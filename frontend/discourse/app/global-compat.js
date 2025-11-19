import "discourse/lib/load-moment";
import jQuery from "jquery";
import virtualDom from "virtual-dom";

// TODO: Eliminate this global
window.virtualDom = virtualDom;

if (!window.$) {
  window.$ = window.jQuery = jQuery;
}
