import { TrackedArray } from "@ember-compat/tracked-built-ins";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUserBadgesRoute extends DiscourseRoute {
  model() {
    const username = this.modelFor("adminUser").get("username");
    return UserBadge.findByUsername(username);
  }

  async setupController(controller, model) {
    super.setupController(controller, new TrackedArray(model));

    // Find all badges.
    controller.loading = true;
    try {
      const badges = await Badge.findAll();
      controller.setProperties({ badges, expandedBadges: [] });
      if (badges.length > 0) {
        let grantableBadges = controller.availableBadges;
        if (grantableBadges.length > 0) {
          controller.selectedBadgeId = grantableBadges[0].get("id");
        }
      }
    } finally {
      controller.loading = false;
    }
  }
}
