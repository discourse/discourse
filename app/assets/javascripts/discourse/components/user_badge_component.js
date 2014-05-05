Discourse.UserBadgeComponent = Ember.Component.extend({
  tagName: 'span',

  badgeTypeClassName: function() {
    return "badge-type-" + this.get('badge.badge_type.name').toLowerCase();
  }.property('badge.badge_type.name')
});
