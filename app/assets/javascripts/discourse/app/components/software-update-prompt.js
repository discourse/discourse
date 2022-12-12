import getURL from "discourse-common/lib/get-url";
import { cancel } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";
import discourseComputed, { bind, on } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { action } from "@ember/object";
import { isTesting } from "discourse-common/config/environment";

export default Component.extend({
  tagName: "",

  showPrompt: false,
  animatePrompt: false,
  _timeoutHandler: null,

  init() {
    this._super(...arguments);

    this.messageBus.subscribe("/refresh_client", this.onRefresh);
    this.messageBus.subscribe("/global/asset-version", this.onAsset);
  },

  willDestroy() {
    this._super(...arguments);

    this.messageBus.unsubscribe("/refresh_client", this.onRefresh);
    this.messageBus.unsubscribe("/global/asset-version", this.onAsset);
  },

  @bind
  onRefresh() {
    this.session.requiresRefresh = true;
  },

  @bind
  onAsset(version) {
    if (this.session.assetVersion !== version) {
      this.session.requiresRefresh = true;
    }

    if (!this._timeoutHandler && this.session.requiresRefresh) {
      if (isTesting()) {
        this.updatePromptState(true);
      } else {
        // Since we can do this transparently for people browsing the forum
        // hold back the message 24 hours.
        this._timeoutHandler = discourseLater(() => {
          this.updatePromptState(true);
        }, 1000 * 60 * 24 * 60);
      }
    }
  },

  @discourseComputed
  rootUrl() {
    return getURL("/");
  },

  updatePromptState(value) {
    // when adding the message, we inject the HTML then add the animation
    // when dismissing, things need to happen in the opposite order
    const firstProp = value ? "showPrompt" : "animatePrompt",
      secondProp = value ? "animatePrompt" : "showPrompt";

    this.set(firstProp, value);
    if (isTesting()) {
      this.set(secondProp, value);
    } else {
      discourseLater(() => {
        this.set(secondProp, value);
      }, 500);
    }
  },

  @action
  refreshPage() {
    document.location.reload();
  },

  @action
  dismiss() {
    this.updatePromptState(false);
  },

  @on("willDestroyElement")
  _resetTimeoutHandler() {
    this._timeoutHandler && cancel(this._timeoutHandler);
    this._timeoutHandler = null;
  },
});
