import NarrowDesktop from "discourse/lib/narrow-desktop";

export default {
  initialize(owner) {
    NarrowDesktop.init();

    const site = owner.lookup("service:site");
    site.set("narrowDesktopView", NarrowDesktop.narrowDesktopView);

    this._resizeObserver = new ResizeObserver((entries) => {
      if (owner.isDestroyed) {
        return;
      }
      for (let entry of entries) {
        const oldNarrowDesktopView = site.narrowDesktopView;
        const newNarrowDesktopView = NarrowDesktop.isNarrowDesktopView(
          entry.contentRect.width
        );
        if (oldNarrowDesktopView !== newNarrowDesktopView) {
          const applicationController = owner.lookup("controller:application");
          site.set("narrowDesktopView", newNarrowDesktopView);
          applicationController.set(
            "showSidebar",
            applicationController.calculateShowSidebar()
          );
          applicationController.appEvents.trigger("site-header:force-refresh");
          owner.lookup("service:header").hamburgerVisible = false;
        }
      }
    });

    this._resizeObserver.observe(document.body);
  },
};
