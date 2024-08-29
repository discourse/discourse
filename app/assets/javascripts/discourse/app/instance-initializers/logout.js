import { service } from "@ember/service";
import ClassBasedInitializer from "discourse/lib/class-based-initializer";
import logout from "discourse/lib/logout";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

let _showingLogout = false;

// Subscribe to "logout" change events via the Message Bus
export default class extends ClassBasedInitializer {
  static after = "message-bus";

  @service messageBus;
  @service dialog;
  @service currentUser;

  initialize() {
    if (this.currentUser) {
      this.messageBus.subscribe(
        `/logout/${this.currentUser.id}`,
        this.onMessage
      );
    }
  }

  teardown() {
    if (this.currentUser) {
      this.messageBus.unsubscribe(
        `/logout/${this.currentUser.id}`,
        this.onMessage
      );
    }
  }

  @bind
  onMessage() {
    if (_showingLogout) {
      return;
    }

    _showingLogout = true;

    this.dialog.alert({
      message: I18n.t("logout"),
      confirmButtonLabel: "home",
      didConfirm: logout,
      didCancel: logout,
      shouldDisplayCancel: false,
    });
  }
}
