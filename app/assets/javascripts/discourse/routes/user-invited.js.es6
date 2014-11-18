export default Discourse.Route.extend({
  renderTemplate: function() {
    this.render({ into: 'user' });
  },

  model: function() {
    return Discourse.Invite.findInvitedBy(this.modelFor('user'));
  },

  setupController: function(controller, model) {
    controller.setProperties({
      model: model,
      user: this.controllerFor('user').get('model'),
      searchTerm: '',
      totalInvites: model.invites.length
    });
    this.controllerFor('user').set('indexStream', false);
  },

  actions: {
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
