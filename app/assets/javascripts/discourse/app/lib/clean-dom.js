import { scheduleOnce } from "@ember/runloop";

function _clean(opts = {}) {
  if (window.MiniProfiler && !opts.skipMiniProfilerPageTransition) {
    window.MiniProfiler.pageTransition();
  }

  // Close some elements that may be open
  $("header ul.icons li").removeClass("active");
  $('[data-toggle="dropdown"]').parent().removeClass("open");
  // close the lightbox
  if ($.magnificPopup && $.magnificPopup.instance) {
    $.magnificPopup.instance.close();
    $("body").removeClass("mfp-zoom-out-cur");
  }

  // Remove any link focus
  // NOTE: the '.not("body")' is here to prevent a bug in IE10 on Win7
  // cf. https://stackoverflow.com/questions/5657371
  $(document.activeElement).not("body").not(".no-blur").blur();

  this.lookup("route:application").send("closeModal");
  const hideDropDownFunction = $("html").data("hide-dropdown");
  if (hideDropDownFunction) {
    hideDropDownFunction();
  }

  this.lookup("service:app-events").trigger("dom:clean");
  this.lookup("service:document-title").updateContextCount(0);
}

export function cleanDOM(container, opts) {
  scheduleOnce("afterRender", container, _clean, opts);
}
