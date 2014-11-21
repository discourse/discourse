/**
  Subscribe to "logout" change events via the Message Bus
**/
export default {
  name: "logout",
  after: "message-bus",

  initialize: function () {
    if (!Discourse.MessageBus) { return; }

    Discourse.MessageBus.subscribe("/logout", function (user_id) {
      var refresher = function() {
        var redirect = Discourse.SiteSettings.logout_redirect;
        if(redirect.length === 0){
          window.location.pathname = Discourse.getURL('/');
        } else {
          window.location.href = redirect;
        }
      };
      bootbox.dialog(I18n.t("logout"), {label: I18n.t("refresh"), callback: refresher}, {onEscape: refresher, backdrop: 'static'})
    });
  }
};
