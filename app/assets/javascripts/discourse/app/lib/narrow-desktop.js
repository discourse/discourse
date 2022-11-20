let narrowDesktopForced = false;

const NarrowDesktop = {
  narrowDesktopView: false,

  init() {
    this.narrowDesktopView = narrowDesktopForced || window.innerWidth < 1100;
  },
};

export function forceNarrowDesktop() {
  narrowDesktopForced = true;
}

export function resetNarrowDesktop() {
  narrowDesktopForced = false;
}

export default NarrowDesktop;
