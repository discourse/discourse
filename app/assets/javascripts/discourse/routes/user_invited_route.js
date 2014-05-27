/**
  This route shows who a user has invited

  @class UserInvitedRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserInvitedRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  model: function() {
    return Discourse.Invite.findInvitedBy(this.modelFor('user'));
  },

  setupController: function(controller, model) {
    controller.setProperties({
      model: model,
      user: this.controllerFor('user').get('model'),
      searchTerm: ''
    });
    this.controllerFor('user').set('indexStream', false);
  },

  actions: {

    /**
      Shows the invite modal to invite users to the forum.

      @method showInvite
    **/
    showInvite: function() {
      Discourse.Route.showModal(this, 'invite', Discourse.User.current());
      this.controllerFor('invite').reset();
    },

    uploadSuccess: function(filename) {
      bootbox.alert(I18n.t("user.invited.bulk_invite.success", { filename: filename }));
    },

    uploadError: function(filename, message) {
      bootbox.alert(I18n.t("user.invited.bulk_invite.error", { filename: filename, message: message }));
    }
  }

});
