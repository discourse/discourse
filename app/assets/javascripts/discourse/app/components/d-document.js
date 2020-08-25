import Component from "@ember/component";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",
  documentTitle: service(),

  didInsertElement() {
    this._super(...arguments);

    this.documentTitle.setTitle(document.title);
    document.addEventListener("visibilitychange", this._focusChanged);
    document.addEventListener("resume", this._focusChanged);
    document.addEventListener("freeze", this._focusChanged);
    this.session.hasFocus = true;

    this.appEvents.on("notifications:changed", this, this._updateNotifications);
  },

  willDestroyElement() {
    this._super(...arguments);

    document.removeEventListener("visibilitychange", this._focusChanged);
    document.removeEventListener("resume", this._focusChanged);
    document.removeEventListener("freeze", this._focusChanged);

    this.appEvents.off(
      "notifications:changed",
      this,
      this._updateNotifications
    );
  },

  _updateNotifications() {
    if (!this.currentUser) {
      return;
    }

    this.documentTitle.updateNotificationCount(
      this.currentUser.unread_notifications +
        this.currentUser.unread_high_priority_notifications
    );
  },

  @bind
  _focusChanged() {
    if (document.visibilityState === "hidden") {
      if (this.session.hasFocus) {
        this.documentTitle.setFocus(false);
      }
    } else if (!this.hasFocus) {
      this.documentTitle.setFocus(true);
    }
  }
});
