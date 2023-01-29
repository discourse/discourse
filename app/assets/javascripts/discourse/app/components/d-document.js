import Component from "@ember/component";
import I18n from "I18n";
import { bind } from "discourse-common/utils/decorators";
import logout from "discourse/lib/logout";
import { inject as service } from "@ember/service";
import { setLogoffCallback } from "discourse/lib/ajax";

let pluginCounterFunctions = [];
export function addPluginDocumentTitleCounter(counterFunction) {
  pluginCounterFunctions.push(counterFunction);
}

export default Component.extend({
  tagName: "",
  documentTitle: service(),
  dialog: service(),
  _showingLogout: false,

  didInsertElement() {
    this._super(...arguments);

    this.documentTitle.setTitle(document.title);
    document.addEventListener("visibilitychange", this._focusChanged);
    document.addEventListener("resume", this._focusChanged);
    document.addEventListener("freeze", this._focusChanged);
    this.session.hasFocus = true;

    this.appEvents.on("notifications:changed", this, this._updateNotifications);
    setLogoffCallback(() => this.displayLogoff());
  },

  willDestroyElement() {
    this._super(...arguments);

    setLogoffCallback(null);
    document.removeEventListener("visibilitychange", this._focusChanged);
    document.removeEventListener("resume", this._focusChanged);
    document.removeEventListener("freeze", this._focusChanged);

    this.appEvents.off(
      "notifications:changed",
      this,
      this._updateNotifications
    );
  },

  _updateNotifications(opts) {
    if (!this.currentUser) {
      return;
    }

    let count = pluginCounterFunctions.reduce((sum, fn) => sum + fn(), 0);
    if (this.currentUser.redesigned_user_menu_enabled) {
      count += this.currentUser.all_unread_notifications_count;
      if (this.currentUser.unseen_reviewable_count) {
        count += this.currentUser.unseen_reviewable_count;
      }
    } else {
      count +=
        this.currentUser.unread_notifications +
        this.currentUser.unread_high_priority_notifications;
    }
    this.documentTitle.updateNotificationCount(count, { forced: opts?.forced });
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
  },

  displayLogoff() {
    if (this._showingLogout) {
      return;
    }

    this._showingLogout = true;
    this.messageBus.stop();

    this.dialog.alert({
      message: I18n.t("logout"),
      confirmButtonLabel: "refresh",
      didConfirm: () => logout(),
      didCancel: () => logout(),
    });
  },
});
