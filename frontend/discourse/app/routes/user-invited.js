import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

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
    return i18n("user.invited.title");
  }
}
