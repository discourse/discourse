import Controller from "@ember/controller";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class AdminBadgesController extends Controller {
  @service router;

  // Set by the route
  @tracked badgeGroupings;
  @tracked badgeTypes;
  @tracked protectedSystemFields;
  @tracked badgeTriggers;

  get selectedRoute() {
    const currentRoute = this.router.currentRouteName;
    const indexRoute = "adminBadges.index";
    if (currentRoute === indexRoute) {
      return "adminBadges.show";
    } else {
      return currentRoute;
    }
  }
}
