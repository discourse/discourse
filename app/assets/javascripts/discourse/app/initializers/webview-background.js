import { later } from "@ember/runloop";
import { isAppWebview, postRNWebviewMessage } from "discourse/lib/utilities";

// Send bg color to webview so iOS status bar matches site theme
export default {
  name: "webview-background",
  after: "inject-objects",

  initialize() {
    if (isAppWebview()) {
      later(() => {
        const header = document.querySelectorAll(".d-header")[0];
        if (header) {
          const styles = window.getComputedStyle(header);
          postRNWebviewMessage("headerBg", styles.backgroundColor);
        }
      }, 500);
    }
  }
};
