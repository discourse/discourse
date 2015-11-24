export default Discourse.Route.extend({
  beforeModel: function(transition) {
    const self = this;
    if (Discourse.User.current()) {
      // User is logged in
      self.replaceWith('discovery.latest').then(function(e) {
        Discourse.User.findByUsername(transition.queryParams.username).then((user) => {
          if (user.can_send_private_message_to_user) {
            Ember.run.next(function() {
              e.send('createNewMessageViaParams', user.username, transition.queryParams.title, transition.queryParams.body);
            });
          } else {
            bootbox.alert(I18n.t("composer.cant_send_pm", {username: user.username}));
          }
        }).catch(() => {
          bootbox.alert(I18n.t("generic_error"));
        });
      });
    } else {
      // User is not logged in
      self.session.set("shouldRedirectToUrl", window.location.href);
      self.replaceWith('login');
    }
  }
});
