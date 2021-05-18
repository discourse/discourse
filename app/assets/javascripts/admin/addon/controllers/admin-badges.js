import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

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
  },
});
