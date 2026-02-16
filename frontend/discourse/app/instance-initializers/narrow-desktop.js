import NarrowDesktop from "discourse/lib/narrow-desktop";

export default {
  initialize(owner) {
    NarrowDesktop.init();

    const site = owner.lookup("service:site");
    site.set("narrowDesktopView", NarrowDesktop.narrowDesktopView);

    // Use matchMedia with the same rem-based breakpoint as CSS (48rem = md)
    // so that JS sidebar visibility stays in sync with CSS grid layout,
    // even when the user zooms the page.
    const mediaQuery = window.matchMedia("(min-width: 48rem)");

    mediaQuery.addEventListener("change", () => {
      if (owner.isDestroyed) {
        return;
      }

      NarrowDesktop.update(owner, !mediaQuery.matches);
    });
  },
};
