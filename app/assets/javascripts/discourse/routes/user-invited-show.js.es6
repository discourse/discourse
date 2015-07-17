import ShowFooter from 'discourse/mixins/show-footer';
import showModal from 'discourse/lib/show-modal';

export default Discourse.Route.extend(ShowFooter, {

  model: function(params) {
    this.inviteFilter = params.filter;
    return Discourse.Invite.findInvitedBy(this.modelFor('user'), params.filter);
  },

  setupController(controller, model) {
    controller.setProperties({
      model: model,
      user: this.controllerFor('user').get('model'),
      filter: this.inviteFilter,
      searchTerm: '',
      totalInvites: model.invites.length
    });
  },

  actions: {
    showInvite() {
      showModal('invite', { model: this.currentUser });
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
