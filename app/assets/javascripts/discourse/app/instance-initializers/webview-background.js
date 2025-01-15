import discourseLater from "discourse/lib/later";
import { postRNWebviewMessage } from "discourse/lib/utilities";

// Send bg color to webview so iOS status bar matches site theme
export default {
  after: "inject-objects",
  retryCount: 0,
  isAppWebview: undefined,
  mediaQuery: "(prefers-color-scheme: dark)",

  initialize(owner) {
    if (this.isAppWebview === undefined) {
      const caps = owner.lookup("service:capabilities");
      this.isAppWebview = caps.isAppWebview;
    }

    if (this.isAppWebview) {
      window
        .matchMedia(this.mediaQuery)
        .addEventListener("change", this.updateAppBackground.bind(this));
      this.updateAppBackground();
    }
  },

  updateAppBackground(delay = 500) {
    discourseLater(() => {
      if (this.headerBgColor()) {
        postRNWebviewMessage("headerBg", this.headerBgColor());
      } else {
        this.retry();
      }
    }, delay);
  },

  headerBgColor() {
    const header = document.querySelector(".d-header-wrap .d-header");
    if (header) {
      return window.getComputedStyle(header)?.backgroundColor;
    }
  },

  retry() {
    if (this.retryCount < 2) {
      this.retryCount++;
      this.updateAppBackground(1000);
    }
  },

  teardown() {
    if (this.isAppWebview) {
      window
        .matchMedia(this.mediaQuery)
        .removeEventListener("change", this.updateAppBackground.bind(this));
    }
  },
};
