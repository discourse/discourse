import logout from 'discourse/lib/logout';

//  Subscribe to "logout" change events via the Message Bus
export default {
  name: "logout",
  after: "message-bus",

  initialize: function (container) {
    const messageBus = container.lookup('message-bus:main');
    const siteSettings = container.lookup('site-settings:main');
    const keyValueStore = container.lookup('key-value-store:main');

    if (!messageBus) { return; }
    const callback = () => logout(siteSettings, keyValueStore);

    messageBus.subscribe("/logout", function () {
      bootbox.dialog(I18n.t("logout"), {label: I18n.t("refresh"), callback}, {onEscape: callback, backdrop: 'static'});
    });
  }
};
