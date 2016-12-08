import User from 'discourse/models/user';
import Group from 'discourse/models/group';

export default Discourse.Route.extend({

  beforeModel(transition) {
    const params = transition.queryParams;

    if (this.currentUser) {
      this.replaceWith("discovery.latest").then(e => {
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
          Group.mentionable(params.groupname).then(result => {
            if (result.mentionable) {
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
      this.session.set("shouldRedirectToUrl", window.location.href);
      this.replaceWith('login');
    }
  }

});
