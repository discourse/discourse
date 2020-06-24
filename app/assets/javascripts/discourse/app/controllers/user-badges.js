import { alias, sort } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";

export default Controller.extend({
  user: controller(),
  username: alias("user.model.username_lower"),
  sortedBadges: sort("model", "badgeSortOrder"),

  init() {
    this._super(...arguments);

    this.badgeSortOrder = ["badge.badge_type.sort_order", "badge.name"];
  }
});
