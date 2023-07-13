import I18n from "I18n";
import logout from "discourse/lib/logout";
import { bind } from "discourse-common/utils/decorators";

let _showingLogout = false;

// Subscribe to "logout" change events via the Message Bus
export default {
  after: "message-bus",

  initialize(owner) {
    this.messageBus = owner.lookup("service:message-bus");
    this.dialog = owner.lookup("service:dialog");
    this.currentUser = owner.lookup("service:current-user");

    if (this.currentUser) {
      this.messageBus.subscribe(
        `/logout/${this.currentUser.id}`,
        this.onMessage
      );
    }
  },

  teardown() {
    if (this.currentUser) {
      this.messageBus.unsubscribe(
        `/logout/${this.currentUser.id}`,
        this.onMessage
      );
    }
  },

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
  },
};
