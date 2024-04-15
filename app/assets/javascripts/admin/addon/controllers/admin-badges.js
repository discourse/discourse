import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { service } from "@ember/service";

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
