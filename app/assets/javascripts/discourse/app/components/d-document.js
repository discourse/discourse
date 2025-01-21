import Component from "@ember/component";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import { setLogoffCallback } from "discourse/lib/ajax";
import { clearAllBodyScrollLocks } from "discourse/lib/body-scroll-lock";
import { bind } from "discourse/lib/decorators";
import logout from "discourse/lib/logout";
import { i18n } from "discourse-i18n";

let pluginCounterFunctions = [];
export function addPluginDocumentTitleCounter(counterFunction) {
  pluginCounterFunctions.push(counterFunction);
}

@tagName("")
export default class DDocument extends Component {
  @service documentTitle;
  @service dialog;

  _showingLogout = false;

  didInsertElement() {
    super.didInsertElement(...arguments);

    this.documentTitle.setTitle(document.title);
    document.addEventListener("visibilitychange", this._focusChanged);
    document.addEventListener("resume", this._focusChanged);
    document.addEventListener("freeze", this._focusChanged);
    this.session.hasFocus = true;

    this.appEvents.on("notifications:changed", this, this._updateNotifications);
    setLogoffCallback(() => this.displayLogoff());
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    setLogoffCallback(null);
    document.removeEventListener("visibilitychange", this._focusChanged);
    document.removeEventListener("resume", this._focusChanged);
    document.removeEventListener("freeze", this._focusChanged);

    this.appEvents.off(
      "notifications:changed",
      this,
      this._updateNotifications
    );
  }

  _updateNotifications(opts) {
    if (!this.currentUser) {
      return;
    }

    let count = pluginCounterFunctions.reduce((sum, fn) => sum + fn(), 0);
    count += this.currentUser.all_unread_notifications_count;
    if (this.currentUser.unseen_reviewable_count) {
      count += this.currentUser.unseen_reviewable_count;
    }
    this.documentTitle.updateNotificationCount(count, { forced: opts?.forced });
  }

  @bind
  _focusChanged() {
    // changing app while keyboard is up could cause the keyboard to not collapse and not release lock
    clearAllBodyScrollLocks();

    if (document.visibilityState === "hidden") {
      if (this.session.hasFocus) {
        this.documentTitle.setFocus(false);
      }
    } else if (!this.hasFocus) {
      this.documentTitle.setFocus(true);
    }
  }

  displayLogoff() {
    if (this._showingLogout) {
      return;
    }

    this._showingLogout = true;
    this.messageBus.stop();

    this.dialog.alert({
      message: i18n("logout"),
      confirmButtonLabel: "refresh",
      didConfirm: () => logout(),
      didCancel: () => logout(),
    });
  }
}
