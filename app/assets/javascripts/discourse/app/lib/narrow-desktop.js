let narrowDesktopForced = false;

const NarrowDesktop = {
  narrowDesktopView: false,

  init() {
    const bodyElement = document.querySelector("body");
    this.narrowDesktopView =
      narrowDesktopForced ||
      this.isNarrowDesktopView(bodyElement.getBoundingClientRect().width);
  },

  isNarrowDesktopView(width) {
    return width < 1000;
  },
};

export default NarrowDesktop;
