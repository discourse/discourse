import Invite from 'discourse/models/invite';
import showModal from "discourse/lib/show-modal";

export default Discourse.Route.extend({

  model(params) {
    this.inviteFilter = params.filter;
    return Invite.findInvitedBy(this.modelFor("user"), params.filter);
  },

  afterModel(model) {
    if (!model.can_see_invite_details) {
      this.replaceWith("userInvited.show", "redeemed");
    }
  },

  setupController(controller, model) {
    controller.setProperties({
      model: model,
      user: this.controllerFor("user").get("model"),
      filter: this.inviteFilter,
      searchTerm: "",
      totalInvites: model.invites.length
    });
  },

  actions: {
    showInvite() {
      showModal("invite", { model: this.currentUser });
      this.controllerFor("invite").reset();
    },

    uploadSuccess(filename) {
      bootbox.alert(I18n.t("user.invited.bulk_invite.success", { filename: filename }));
    },

    uploadError(filename, message) {
      bootbox.alert(I18n.t("user.invited.bulk_invite.error", { filename: filename, message: message }));
    }
  }
});
