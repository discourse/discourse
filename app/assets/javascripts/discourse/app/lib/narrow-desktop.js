let narrowDesktopForced = false;

const NarrowDesktop = {
  narrowDesktopView: false,

  init() {
    this.narrowDesktopView =
      narrowDesktopForced ||
      this.isNarrowDesktopView(bodyElement.getBoundingClientRect().width);
  },

  isNarrowDesktopView(width) {
    return width < 1000;
  },
};

export default NarrowDesktop;
