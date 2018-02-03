import User from 'discourse/models/user';
import Group from 'discourse/models/group';

export default Discourse.Route.extend({

  beforeModel(transition) {
    const self = this;
    const params = transition.queryParams;

    if (self.currentUser) {
      self.replaceWith("discovery.latest").then(e => {
        if (params.username) {
          // send a message to a user
          User.findByUsername(params.username).then(user => {
            if (user.can_send_private_message_to_user) {
              Ember.run.next(() => e.send("createNewMessageViaParams", user.username, params.title, params.body));
            } else {
              bootbox.alert(I18n.t("composer.cant_send_pm", { username: user.username }));
            }
          }).catch(function() {
            bootbox.alert(I18n.t("generic_error"));
          });
        } else if (params.groupname) {
          // send a message to a group
          Group.messageable(params.groupname).then(result => {
            if (result.messageable) {
              Ember.run.next(() => e.send("createNewMessageViaParams", params.groupname, params.title, params.body));
            } else {
              bootbox.alert(I18n.t("composer.cant_send_pm", { username: params.groupname }));
            }
          }).catch(function() {
            bootbox.alert(I18n.t("generic_error"));
          });
        }
      });
    } else {
      $.cookie('destination_url', window.location.href);
      if (Discourse.showingSignup) {
        Discourse.showingSignup = false;
      } else {
        self.replaceWith('login');
      }
    }
  }

});
