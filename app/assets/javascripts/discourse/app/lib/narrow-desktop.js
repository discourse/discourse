let narrowDesktopForced = false;

const NarrowDesktop = {
  narrowDesktopView: false,

  init() {
    this.narrowDesktopView =
      narrowDesktopForced || this.isNarrowDesktopView(window.innerWidth);
  },

  isNarrowDesktopView(width) {
    return width < 1100;
  },
};

export function forceNarrowDesktop() {
  narrowDesktopForced = true;
}

export function resetNarrowDesktop() {
  narrowDesktopForced = false;
}

export default NarrowDesktop;
