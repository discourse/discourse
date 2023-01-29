import NarrowDesktop from "discourse/lib/narrow-desktop";

export default {
  name: "narrow-desktop",

  initialize(container) {
    NarrowDesktop.init();
    let site;
    if (!container.isDestroyed) {
      site = container.lookup("service:site");
      site.set("narrowDesktopView", NarrowDesktop.narrowDesktopView);
    }

    if ("ResizeObserver" in window) {
      this._resizeObserver = new ResizeObserver((entries) => {
        if (container.isDestroyed) {
          return;
        }
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
            applicationController.set(
              "showSidebar",
              applicationController.calculateShowSidebar()
            );
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
