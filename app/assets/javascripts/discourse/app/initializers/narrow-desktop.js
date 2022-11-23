import NarrowDesktop from "discourse/lib/narrow-desktop";

export default {
  name: "narrow-desktop",

  initialize(container) {
    NarrowDesktop.init();
    const site = container.lookup("service:site");
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
            applicationController.set("showSidebar", !newNarrowDesktopView);
            applicationController.appEvents.trigger(
              "sidebar-toggle:force-refresh"
            );
          }
        }
      });

      const mainElement = document.querySelector("#main");
      if (mainElement) {
        this._resizeObserver.observe(mainElement);
      }
    }
  },
};
