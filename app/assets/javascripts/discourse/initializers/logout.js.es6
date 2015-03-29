//  Subscribe to "logout" change events via the Message Bus
export default {
  name: "logout",
  after: "message-bus",

  initialize: function (container) {
    const messageBus = container.lookup('message-bus:main'),
          siteSettings = container.lookup('site-settings:main');

    if (!messageBus) { return; }

    messageBus.subscribe("/logout", function () {
      var refresher = function() {
        var redirect = siteSettings.logout_redirect;
        if(redirect.length === 0){
          window.location.pathname = Discourse.getURL('/');
        } else {
          window.location.href = redirect;
        }
      };
      bootbox.dialog(I18n.t("logout"), {label: I18n.t("refresh"), callback: refresher}, {onEscape: refresher, backdrop: 'static'});
    });
  }
};
