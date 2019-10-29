import { inject } from "@ember/controller";
import Controller from "@ember/controller";
export default Controller.extend({
  user: inject(),
  username: Ember.computed.alias("user.model.username_lower"),
  sortedBadges: Ember.computed.sort("model", "badgeSortOrder"),

  init() {
    this._super(...arguments);

    this.badgeSortOrder = ["badge.badge_type.sort_order", "badge.name"];
  }
});
