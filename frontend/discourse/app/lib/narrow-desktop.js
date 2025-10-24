let narrowDesktopForced = false;

const NarrowDesktop = {
  narrowDesktopView: false,

  init() {
    this.narrowDesktopView =
      narrowDesktopForced ||
      this.isNarrowDesktopView(document.body.getBoundingClientRect().width);
  },

  isNarrowDesktopView(width) {
    return width < 768;
  },
};

export default NarrowDesktop;
