import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserIndex extends DiscourseRoute {
  @service router;
  @service site;
  @service currentUser;
  @service siteSettings;

  get viewingOtherUserDefaultRoute() {
    let viewUserRoute = this.siteSettings.view_user_route;

    if (viewUserRoute === "activity") {
      viewUserRoute = "userActivity";
    } else {
      viewUserRoute = `user.${viewUserRoute}`;
    }

    if (getOwner(this).lookup(`route:${viewUserRoute}`)) {
      return viewUserRoute;
    } else {
      // eslint-disable-next-line no-console
      console.error(
        `Invalid value for view_user_route '${viewUserRoute}'. Falling back to 'summary'.`
      );
      return "user.summary";
    }
  }

  beforeModel() {
    const viewingMe =
      this.currentUser?.username === this.modelFor("user").username;

    let destination;
    if (viewingMe) {
      destination = "userActivity";
    } else {
      destination = this.viewingOtherUserDefaultRoute;
    }

    this.router.transitionTo(destination);
  }
}
