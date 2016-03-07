import Group from 'discourse/models/group';

export default Discourse.Route.extend({
  beforeModel: function(transition) {
    const self = this;
    if (Discourse.User.current()) {
      // User is logged in
      self.replaceWith('discovery.latest').then(function(e) {
        if (transition.queryParams.username) {
          // send a message to user
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
        } else {
          // send a message to group
          Group.find(transition.queryParams.groupname).then((group) => {
            if (!group.automatic && group.mentionable) {
              Ember.run.next(function() {
                e.send('createNewMessageViaParams', group.name, transition.queryParams.title, transition.queryParams.body);
              });
            } else {
              bootbox.alert(I18n.t("composer.cant_send_pm", {username: group.name}));
            }
          }).catch(() => {
            bootbox.alert(I18n.t("generic_error"));
          });
        }
      });
    } else {
      // User is not logged in
      self.session.set("shouldRedirectToUrl", window.location.href);
      self.replaceWith('login');
    }
  }
});
