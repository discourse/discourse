import { createWidget } from "discourse/widgets/widget";
import { isAppWebview, isChromePWA } from "discourse/lib/utilities";

createWidget("footer-nav", {
  tagName: "div.footer-nav-widget",

  html(attrs) {
    const buttons = [];

    buttons.push(
      this.attach("flat-button", {
        action: "goBack",
        icon: "chevron-left",
        className: "btn-large",
        disabled: !attrs.canGoBack
      })
    );

    buttons.push(
      this.attach("flat-button", {
        action: "goForward",
        icon: "chevron-right",
        className: "btn-large",
        disabled: !attrs.canGoForward
      })
    );

    if (isAppWebview()) {
      buttons.push(
        this.attach("flat-button", {
          action: "share",
          icon: "link",
          className: "btn-large"
        })
      );

      buttons.push(
        this.attach("flat-button", {
          action: "dismiss",
          icon: "chevron-down",
          className: "btn-large"
        })
      );
    }

    if (isChromePWA()) {
      buttons.push(
        this.attach("flat-button", {
          action: "refresh",
          icon: "sync",
          className: "btn-large"
        })
      );
    }
    return buttons;
  },

  dismiss() {
    window.ReactNativeWebView.postMessage(JSON.stringify({ dismiss: true }));
  },

  share() {
    window.ReactNativeWebView.postMessage(
      JSON.stringify({ shareUrl: window.location.href })
    );
  },

  refresh() {
    window.location.reload();
  }
});
