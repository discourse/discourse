import getURL from "discourse-common/lib/get-url";
import { later } from "@ember/runloop";
import { computed, on } from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  showPrompt: false,

  classNameBindings: ["getClassNames"],

  @computed
  rootUrl() {
    return getURL("/");
  },

  @computed("showPrompt")
  getClassNames(showPrompt) {
    let classes = ["software-update-prompt"];

    if (showPrompt) {
      classes.push("require-software-refresh");
    }

    return classes.join(" ");
  },

  @on("init")
  initSubscribtions() {
    let timeout;

    this.messageBus.subscribe("/refresh_client", () => {
      this.session.requiresRefresh = true;
    });

    let updatePrompt = this;
    this.messageBus.subscribe("/global/asset-version", (version) => {
      if (this.session.assetVersion !== version) {
        this.session.requiresRefresh = true;
      }

      if (!timeout && this.session.requiresRefresh) {
        // Since we can do this transparently for people browsing the forum
        // hold back the message 24 hours.
        timeout = later(() => {
          updatePrompt.set("showPrompt", true);
        }, 500);
        // }, 1000 * 60 * 24 * 60);
      }
    });
  },
});
