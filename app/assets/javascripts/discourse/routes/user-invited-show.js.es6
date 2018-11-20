import Invite from "discourse/models/invite";
import showModal from "discourse/lib/show-modal";

export default Discourse.Route.extend({
  model(params) {
    const self = this;
    Invite.findInvitedCount(self.modelFor("user")).then(function(result) {
      self.set("invitesCount", result);
    });
    self.inviteFilter = params.filter;
    return Invite.findInvitedBy(self.modelFor("user"), params.filter);
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
      totalInvites: model.invites.length,
      invitesCount: this.get("invitesCount")
    });
  },

  actions: {
    showInvite() {
      showModal("invite", { model: this.currentUser });
      this.controllerFor("invite").reset();
    }
  }
});
