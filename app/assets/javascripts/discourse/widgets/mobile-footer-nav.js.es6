import { createWidget } from "discourse/widgets/widget";
import { nativeShare } from "discourse/lib/pwa-utils";
import { isAppWebview, isPWA } from "discourse/lib/utilities";

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

    buttons.push(
      this.attach("flat-button", {
        action: "share",
        icon: "link",
        className: "btn-large"
      })
    );

    if (isAppWebview()) {
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
    if (isAppWebview()) {
      window.ReactNativeWebView.postMessage(
        JSON.stringify({ shareUrl: window.location.href })
      );
    } else if (isPWA()) {
      nativeShare({ url: window.location.href });
    }
  }
});
