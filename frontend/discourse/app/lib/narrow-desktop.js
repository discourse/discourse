let narrowDesktopForced = false;

const NarrowDesktop = {
  narrowDesktopView: false,

  init() {
    this.narrowDesktopView =
      narrowDesktopForced || !window.matchMedia("(min-width: 48rem)").matches;
  },

  update(owner, isNarrow) {
    const site = owner.lookup("service:site");
    if (site.narrowDesktopView === isNarrow) {
      return;
    }

    site.set("narrowDesktopView", isNarrow);

    const applicationController = owner.lookup("controller:application");
    applicationController.set(
      "showSidebar",
      applicationController.calculateShowSidebar()
    );
    applicationController.appEvents.trigger("site-header:force-refresh");
    owner.lookup("service:header").hamburgerVisible = false;
  },
};

export function forceNarrowDesktop() {
  narrowDesktopForced = true;
}

export function resetNarrowDesktop() {
  narrowDesktopForced = false;
}

export default NarrowDesktop;
