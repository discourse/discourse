import { createWidget } from "discourse/widgets/widget";
import { isAppWebview } from "discourse/lib/utilities";

createWidget("mobile-footer-nav", {
  tagName: "div.mobile-footer-nav",

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

    return buttons;
  },

  dismiss() {
    window.ReactNativeWebView.postMessage(JSON.stringify({ dismiss: true }));
  },

  share() {
    window.ReactNativeWebView.postMessage(
      JSON.stringify({ shareUrl: window.location.href })
    );
  }
});
