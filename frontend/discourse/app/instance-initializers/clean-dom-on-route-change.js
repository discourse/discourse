import { lookup } from "discourse/lib/service";
import { scheduleOnce } from "@ember/runloop";
import AppEventsService from "discourse/services/app-events";
import DocumentTitleService from "discourse/services/document-title";

function _clean(transition) {
  if (window.MiniProfiler && transition.from) {
    window.MiniProfiler.pageTransition();
  }

  // Close some elements that may be open
  document.querySelectorAll("header ul.icons li").forEach((element) => {
    element.classList.remove("active");
  });

  document.querySelectorAll(`[data-toggle="dropdown"]`).forEach((element) => {
    element.parentElement.classList.remove("open");
  });

  // Close PhotoSwipe
  window.pswp?.close();

  // Remove any link focus
  const { activeElement } = document;
  if (activeElement && !activeElement.classList.contains("no-blur")) {
    activeElement.blur();
  }

  this.lookup("route:application").send("closeModal");

  lookup(this, AppEventsService).trigger("dom:clean");
  lookup(this, DocumentTitleService).updateContextCount(0);
}

export default {
  after: "inject-objects",

  initialize(owner) {
    const router = owner.lookup("service:router");

    router.on("routeDidChange", (transition) => {
      if (transition.isAborted) {
        return;
      }

      scheduleOnce("afterRender", owner, _clean, transition);
    });
  },
};
