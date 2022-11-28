let narrowDesktopForced = false;

const NarrowDesktop = {
  narrowDesktopView: false,

  init() {
    this.narrowDesktopView =
      narrowDesktopForced ||
      this.isNarrowDesktopView(document.body.getBoundingClientRect().width);
  },

  isNarrowDesktopView(width) {
    return width < 1000;
  },
};

export default NarrowDesktop;
