import { scheduleOnce } from "@ember/runloop";

function _clean() {
  if (window.MiniProfiler) {
    window.MiniProfiler.pageTransition();
  }

  // Close some elements that may be open
  $("header ul.icons li").removeClass("active");
  $('[data-toggle="dropdown"]').parent().removeClass("open");

  // close lightboxs
  if (window.lgData) {
    Object.keys(window.lgData).forEach((key) => {
      // lightGallery adds a uid property to the object. It's not a gallery, so
      // we skip it.
      if (key !== "uid") {
        const gallery = window.lgData[key];
        // lightGallery saves and restores the previous ScrollTop position when
        // it's closed. We don't need that here since this is a full page treansition
        gallery.prevScrollTop = 0;
        gallery.destroy(true);
      }
    });
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

export function cleanDOM(container) {
  scheduleOnce("afterRender", container, _clean);
}
