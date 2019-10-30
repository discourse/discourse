import { alias, sort } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
export default Controller.extend({
  user: inject(),
  username: alias("user.model.username_lower"),
  sortedBadges: sort("model", "badgeSortOrder"),

  init() {
    this._super(...arguments);

    this.badgeSortOrder = ["badge.badge_type.sort_order", "badge.name"];
  }
});
