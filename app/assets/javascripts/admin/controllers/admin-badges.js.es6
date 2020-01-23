import Controller from "@ember/controller";
import { inject as service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  routing: service("-routing"),

  @discourseComputed("routing.currentRouteName")
  selectedRoute() {
    const currentRoute = this.routing.currentRouteName;
    const indexRoute = "adminBadges.index";
    if (currentRoute === indexRoute) {
      return "adminBadges.show";
    } else {
      return this.routing.currentRouteName;
    }
  }
});
