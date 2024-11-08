import { postRNWebviewMessage } from "discourse/lib/utilities";
import discourseLater from "discourse-common/lib/later";

// Send bg color to webview so iOS status bar matches site theme
export default {
  after: "inject-objects",
  retryCount: 0,

  initialize(owner) {
    const caps = owner.lookup("service:capabilities");
    if (caps.isAppWebview) {
      window
        .matchMedia("(prefers-color-scheme: dark)")
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
};
