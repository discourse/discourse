import { action } from "@ember/object";
import { service } from "@ember/service";
import Invite from "discourse/models/invite";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserInvitedShow extends DiscourseRoute {
  @service router;

  model(params) {
    this.inviteFilter = params.filter;
    return Invite.findInvitedBy(this.modelFor("user"), params.filter);
  }

  afterModel(model) {
    if (!model.can_see_invite_details) {
      this.router.replaceWith("userInvited.show", "redeemed");
    }
    this.controllerFor("user.invited").setProperties({
      invitesCount: model.counts,
    });
  }

  setupController(controller, model) {
    controller.setProperties({
      model,
      invitesCount: model.counts,
      user: this.controllerFor("user").get("model"),
      filter: this.inviteFilter,
      searchTerm: "",
    });
  }

  titleToken() {
    return i18n("user.invited." + this.inviteFilter + "_tab");
  }

  @action
  triggerRefresh() {
    this.refresh();
  }
}
