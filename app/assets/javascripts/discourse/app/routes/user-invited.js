import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class UserInvited extends DiscourseRoute {
  setupController(controller) {
    const can_see_invite_details =
      this.currentUser.staff ||
      this.controllerFor("user").id === this.currentUser?.id;

    controller.setProperties({
      can_see_invite_details,
    });
  }

  titleToken() {
    return I18n.t("user.invited.title");
  }
}
