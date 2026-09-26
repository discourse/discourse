import { lookup } from "discourse/lib/service";
import SiteService from "discourse/services/site";
import HeaderService from "discourse/services/header";
let narrowDesktopForced = false;

const NarrowDesktop = {
  narrowDesktopView: false,

  init() {
    this.narrowDesktopView =
      narrowDesktopForced || !window.matchMedia("(min-width: 48rem)").matches;
  },

  update(owner, isNarrow) {
    const site = lookup(owner, SiteService);
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
    lookup(owner, HeaderService).hamburgerVisible = false;
  },
};

export function forceNarrowDesktop() {
  narrowDesktopForced = true;
}

export function resetNarrowDesktop() {
  narrowDesktopForced = false;
}

export default NarrowDesktop;
