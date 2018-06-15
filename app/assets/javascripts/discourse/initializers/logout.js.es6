import logout from "discourse/lib/logout";

let _showingLogout = false;

//  Subscribe to "logout" change events via the Message Bus
export default {
  name: "logout",
  after: "message-bus",

  initialize: function(container) {
    const messageBus = container.lookup("message-bus:main");

    if (!messageBus) {
      return;
    }

    messageBus.subscribe("/logout", function() {
      if (!_showingLogout) {
        _showingLogout = true;

        bootbox.dialog(
          I18n.t("logout"),
          {
            label: I18n.t("refresh"),
            callback: logout
          },
          {
            onEscape: logout,
            backdrop: "static"
          }
        );
      }
    });
  }
};
