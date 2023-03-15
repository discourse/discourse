import Badge from "discourse/models/badge";
import DiscourseRoute from "discourse/routes/discourse";
import UserBadge from "discourse/models/user-badge";

export default class AdminUserBadgesRoute extends DiscourseRoute {
  model() {
    const username = this.modelFor("adminUser").get("username");
    return UserBadge.findByUsername(username);
  }

  setupController(controller, model) {
    // Find all badges.
    controller.set("loading", true);
    Badge.findAll().then(function (badges) {
      controller.set("badges", badges);
      if (badges.length > 0) {
        let grantableBadges = controller.get("grantableBadges");
        if (grantableBadges.length > 0) {
          controller.set("selectedBadgeId", grantableBadges[0].get("id"));
        }
      }
      controller.set("loading", false);
    });
    // Set the model.
    controller.set("model", model);
  }
}
