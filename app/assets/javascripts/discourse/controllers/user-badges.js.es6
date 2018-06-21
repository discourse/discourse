export default Ember.Controller.extend({
  user: Ember.inject.controller(),
  username: Ember.computed.alias("user.model.username_lower"),
  sortedBadges: Ember.computed.sort("model", "badgeSortOrder"),
  badgeSortOrder: ["badge.badge_type.sort_order", "badge.name"]
});
