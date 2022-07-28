import I18n from "I18n";
import bootbox from "bootbox";
import logout from "discourse/lib/logout";

let _showingLogout = false;

//  Subscribe to "logout" change events via the Message Bus
export default {
  name: "logout",
  after: "message-bus",

  initialize(container) {
    const messageBus = container.lookup("service:message-bus");

    if (!messageBus) {
      return;
    }

    messageBus.subscribe("/logout", function () {
      if (!_showingLogout) {
        _showingLogout = true;

        bootbox.dialog(
          I18n.t("logout"),
          {
            label: I18n.t("home"),
            callback: logout,
          },
          {
            onEscape: logout,
            backdrop: "static",
          }
        );
      }
    });
  },
};
