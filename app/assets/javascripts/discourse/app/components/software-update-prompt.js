import getURL from "discourse-common/lib/get-url";
import { cancel, later } from "@ember/runloop";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { not } from "@ember/object/computed";
import { isTesting } from "discourse-common/config/environment";

export default Component.extend({
  showPrompt: false,

  classNameBindings: ["getClassNames"],
  attributeBindings: ["isHidden:aria-hidden"],

  @discourseComputed
  rootUrl() {
    return getURL("/");
  },

  isHidden: not("showPrompt"),

  _timeoutHandler: null,

  @discourseComputed("showPrompt")
  getClassNames(showPrompt) {
    const classes = ["software-update-prompt"];

    if (showPrompt) {
      classes.push("require-software-refresh");
    }

    return classes.join(" ");
  },

  @on("init")
  initSubscribtions() {
    this.messageBus.subscribe("/refresh_client", () => {
      this.session.requiresRefresh = true;
    });

    this.messageBus.subscribe("/global/asset-version", (version) => {
      if (this.session.assetVersion !== version) {
        this.session.requiresRefresh = true;
      }

      if (!this._timeoutHandler && this.session.requiresRefresh) {
        if (isTesting()) {
          this.set("showPrompt", true);
        } else {
          // Since we can do this transparently for people browsing the forum
          // hold back the message 24 hours.
          this._timeoutHandler = later(() => {
            this.set("showPrompt", true);
          }, 1000 * 60 * 24 * 60);
        }
      }
    });
  },

  willDestroyElement() {
    this._super(...arguments);

    this._timeoutHandler && cancel(this._timeoutHandler);

    this._timeoutHandler = null;
  },
});
