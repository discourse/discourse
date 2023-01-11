import { postRNWebviewMessage } from "discourse/lib/utilities";
import { createWidget } from "discourse/widgets/widget";

createWidget("footer-nav", {
  tagName: "div.footer-nav-widget",

  html(attrs) {
    const buttons = [];

    buttons.push(
      this.attach("flat-button", {
        action: "goBack",
        icon: "chevron-left",
        className: "btn-large",
        disabled: !attrs.canGoBack,
        title: "footer_nav.back",
      })
    );

    buttons.push(
      this.attach("flat-button", {
        action: "goForward",
        icon: "chevron-right",
        className: "btn-large",
        disabled: !attrs.canGoForward,
        title: "footer_nav.forward",
      })
    );

    if (this.capabilities.isAppWebview) {
      buttons.push(
        this.attach("flat-button", {
          action: "share",
          icon: "link",
          className: "btn-large",
          title: "footer_nav.share",
        })
      );

      buttons.push(
        this.attach("flat-button", {
          action: "dismiss",
          icon: "chevron-down",
          className: "btn-large",
          title: "footer_nav.dismiss",
        })
      );
    }

    return buttons;
  },

  dismiss() {
    postRNWebviewMessage("dismiss", true);
  },

  share() {
    postRNWebviewMessage("shareUrl", window.location.href);
  },
});
