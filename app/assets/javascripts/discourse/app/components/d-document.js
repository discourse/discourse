import Component from "@ember/component";
import { bind } from "@ember/runloop";
import { inject as service } from "@ember/service";

export default Component.extend({
  _boundFocusChange: null,
  tagName: "",
  documentTitle: service(),

  didInsertElement() {
    this._super(...arguments);

    this.documentTitle.setTitle(document.title);
    this._boundFocusChange = bind(this, this._focusChanged);
    document.addEventListener("visibilitychange", this._boundFocusChange);
    document.addEventListener("resume", this._boundFocusChange);
    document.addEventListener("freeze", this._boundFocusChange);
    this.session.hasFocus = true;

    this.appEvents.on("notifications:changed", this, this._updateNotifications);
  },

  willDestroyElement() {
    this._super(...arguments);

    document.removeEventListener("visibilitychange", this._boundFocusChange);
    document.removeEventListener("resume", this._boundFocusChange);
    document.removeEventListener("freeze", this._boundFocusChange);
    this._boundFocusChange = null;

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
