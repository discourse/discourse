import ShowFooter from 'discourse/mixins/show-footer';
import showModal from 'discourse/lib/show-modal';

export default Discourse.Route.extend(ShowFooter, {
  renderTemplate() {
    this.render({ into: 'user' });
  },

  model() {
    return Discourse.Invite.findInvitedBy(this.modelFor('user'));
  },

  setupController(controller, model) {
    controller.setProperties({
      model: model,
      user: this.controllerFor('user').get('model'),
      searchTerm: '',
      totalInvites: model.invites.length
    });
  },

  actions: {
    showInvite() {
      showModal('invite', Discourse.User.current());
      this.controllerFor('invite').reset();
    },

    uploadSuccess(filename) {
      bootbox.alert(I18n.t("user.invited.bulk_invite.success", { filename: filename }));
    },

    uploadError(filename, message) {
      bootbox.alert(I18n.t("user.invited.bulk_invite.error", { filename: filename, message: message }));
    }
  }
});
