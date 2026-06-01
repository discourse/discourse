import "message-bus-client";
import jQuery from "jquery";

window.jQuery = jQuery;

window.MessageBus.ajax = jQuery.ajax;
window.MessageBus.subscribe("/file-change", () => {
  window.parent.location.reload();
});
