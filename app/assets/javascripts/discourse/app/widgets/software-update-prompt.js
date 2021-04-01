import { createWidget } from "discourse/widgets/widget";
import RawHtml from "discourse/widgets/raw-html";
import { h } from "virtual-dom";
import getURL from "discourse-common/lib/get-url";
import { later } from "@ember/runloop";
import { iconHTML } from "discourse-common/lib/icon-library";

export default createWidget("software-update-prompt", {
  tagName: "",
  buildKey: () => "software-update-prompt",

  defaultState() {
    return { showPrompt: false };
  },

  init() {
    let timeout;

    const messageBus = this.container.lookup("message-bus:main");
    if (!messageBus) {
      return;
    }

    let session = this.container.lookup("session:main");

    messageBus.subscribe("/refresh_client", () => {
      session.requiresRefresh = true;
    });

    let updatePromptWidget = this;
    messageBus.subscribe("/global/asset-version", (version) => {
      if (session.assetVersion !== version) {
        session.requiresRefresh = true;
      }

      if (!timeout && session.requiresRefresh) {
        // Since we can do this transparently for people browsing the forum
        // hold back the message 24 hours.
        timeout = later(() => {
          updatePromptWidget.state.showPrompt = true;
          updatePromptWidget.scheduleRerender();
        }, 1000 * 60 * 24 * 60);
      }
    });
  },

  html() {
    let classes = ["software-update-prompt"];

    if (this.state.showPrompt) {
      classes.push("require-software-refresh");
    }

    return h("div", { attributes: { class: classes.join(" ") } }, [
      new RawHtml({ html: iconHTML("redo") }),
      " We've updated this site, ",
      h("a", { attributes: { href: getURL("") } }, "please refresh"),
      ", or you may experience unexpected behaviour.",
    ]);
  },
});
