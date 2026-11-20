import { scheduleOnce } from "@ember/runloop";

let focusedBeforeTransition;

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

  // Remove focus from the link that triggered navigation, but keep focus the
  // new page set deliberately (e.g. on a linked post)
  const { activeElement } = document;
  if (
    activeElement === focusedBeforeTransition &&
    !activeElement.classList.contains("no-blur")
  ) {
    activeElement.blur();
  }
  focusedBeforeTransition = null;

  this.lookup("route:application").send("closeModal");

  this.lookup("service:app-events").trigger("dom:clean");
  this.lookup("service:document-title").updateContextCount(0);
}

export default {
  after: "inject-objects",

  initialize(owner) {
    const router = owner.lookup("service:router");

    router.on("routeWillChange", () => {
      focusedBeforeTransition = document.activeElement;
    });

    router.on("routeDidChange", (transition) => {
      if (transition.isAborted) {
        return;
      }

      scheduleOnce("afterRender", owner, _clean, transition);
    });
  },
};
