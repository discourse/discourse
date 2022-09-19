import { bind } from "discourse-common/utils/decorators";

export default {
  name: "mobile-keyboard",
  after: "mobile",

  initialize(container) {
    const site = container.lookup("service:site");
    const capabilities = container.lookup("capabilities:main");

    if (!capabilities.isIpadOS && !site.mobileView) {
      return;
    }

    if (!window.visualViewport) {
      return;
    }

    // TODO: Handle device rotation?
    this.windowInnerHeight = window.innerHeight;

    this.onViewportResize();
    window.visualViewport.addEventListener("resize", this.onViewportResize);
  },

  teardown() {
    window.visualViewport.removeEventListener("resize", this.onViewportResize);
  },

  @bind
  onViewportResize() {
    const composerVH = window.visualViewport.height * 0.01;
    const doc = document.documentElement;

    doc.style.setProperty("--composer-vh", `${composerVH}px`);
    const heightDiff = this.windowInnerHeight - window.visualViewport.height;

    doc.classList.toggle("keyboard-visible", heightDiff > 0);

    // Add bottom padding when using a hardware keyboard and the accessory bar
    // is visible accessory bar height is 55px, using 75 allows a small buffer
    doc.style.setProperty(
      "--composer-ipad-padding",
      `${heightDiff < 75 ? heightDiff : 0}px`
    );
  },
};
