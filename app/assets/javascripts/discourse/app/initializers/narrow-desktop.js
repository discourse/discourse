import NarrowDesktop from "discourse/lib/narrow-desktop";

export default {
  name: "narrow-desktop",

  initialize(container) {
    NarrowDesktop.init();
    const site = container.lookup("service:site");
    site.set("narrowDesktopView", NarrowDesktop.narrowDesktopView);
  },
};
