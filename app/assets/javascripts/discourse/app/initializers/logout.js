import I18n from "I18n";
import logout from "discourse/lib/logout";

let _showingLogout = false;

//  Subscribe to "logout" change events via the Message Bus
export default {
  name: "logout",
  after: "message-bus",

  initialize(container) {
    const messageBus = container.lookup("service:message-bus"),
      dialog = container.lookup("service:dialog");

    if (!messageBus) {
      return;
    }

    messageBus.subscribe("/logout", function () {
      if (!_showingLogout) {
        _showingLogout = true;

        dialog.alert({
          message: I18n.t("logout"),
          confirmButtonLabel: "home",
          didConfirm: logout,
          didCancel: logout,
          shouldDisplayCancel: false,
        });
      }

      _showingLogout = true;
    });
  },
};
