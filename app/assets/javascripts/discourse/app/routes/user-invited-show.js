import DiscourseRoute from "discourse/routes/discourse";
import Invite from "discourse/models/invite";
import showModal from "discourse/lib/show-modal";

export default DiscourseRoute.extend({
  model(params) {
    Invite.findInvitedCount(this.modelFor("user")).then(result =>
      this.set("invitesCount", result)
    );
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
      model,
      user: this.controllerFor("user").get("model"),
      filter: this.inviteFilter,
      searchTerm: "",
      totalInvites: model.invites.length,
      invitesCount: this.invitesCount
    });
  },

  actions: {
    showInvite() {
      const panels = [
        {
          id: "invite",
          title: "user.invited.single_user",
          model: {
            inviteModel: this.currentUser,
            userInvitedShow: this.controllerFor("user-invited-show")
          }
        }
      ];

      if (this.get("currentUser.staff")) {
        panels.push({
          id: "invite-link",
          title: "user.invited.multiple_user",
          model: {
            inviteModel: this.currentUser,
            userInvitedShow: this.controllerFor("user-invited-show")
          }
        });
      }

      showModal("share-and-invite", {
        modalClass: "share-and-invite",
        panels
      });
    },

    editInvite(inviteKey) {
      const inviteLink = `${Discourse.BaseUrl}/invites/${inviteKey}`;
      this.currentUser.setProperties({ finished: true, inviteLink });
      const panels = [
        {
          id: "invite-link",
          title: "user.invited.generate_link",
          model: {
            inviteModel: this.currentUser,
            userInvitedShow: this.controllerFor("user-invited-show")
          }
        }
      ];

      showModal("share-and-invite", {
        modalClass: "share-and-invite",
        panels
      });
    }
  }
});
