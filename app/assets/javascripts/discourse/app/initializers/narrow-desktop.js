import NarrowDesktop from "discourse/lib/narrow-desktop";

export default {
  name: "narrow-desktop",

  initialize(container) {
    NarrowDesktop.init();
    const site = container?.lookup("service:site");
    if (!site) {
      return;
    }
    site.set("narrowDesktopView", NarrowDesktop.narrowDesktopView);

    if ("ResizeObserver" in window) {
      this._resizeObserver = new ResizeObserver((entries) => {
        for (let entry of entries) {
          const oldNarrowDesktopView = site.narrowDesktopView;
          const newNarrowDesktopView = NarrowDesktop.isNarrowDesktopView(
            entry.contentRect.width
          );
          if (oldNarrowDesktopView !== newNarrowDesktopView) {
            const applicationController = container.lookup(
              "controller:application"
            );
            site.set("narrowDesktopView", newNarrowDesktopView);
            if (newNarrowDesktopView) {
              applicationController.set("showSidebar", false);
            }
            applicationController.appEvents.trigger(
              "site-header:force-refresh"
            );
          }
        }
      });

      const bodyElement = document.querySelector("body");
      if (bodyElement) {
        this._resizeObserver.observe(bodyElement);
      }
    }
  },
};
