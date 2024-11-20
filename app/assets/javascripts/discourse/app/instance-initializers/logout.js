import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import logout from "discourse/lib/logout";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

let _showingLogout = false;

// Subscribe to "logout" change events via the Message Bus
class LogoutInit {
  @service messageBus;
  @service dialog;
  @service currentUser;

  constructor(owner) {
    setOwner(this, owner);

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
      message: i18n("logout"),
      confirmButtonLabel: "home",
      didConfirm: logout,
      didCancel: logout,
      shouldDisplayCancel: false,
    });
  }
}

export default {
  after: "message-bus",

  initialize(owner) {
    this.instance = new LogoutInit(owner);
  },

  teardown() {
    this.instance.teardown();
    this.instance = null;
  },
};
