export default Ember.Component.extend({
  tagName: 'span',

  badgeTypeClassName: function() {
    return "badge-type-" + this.get('badge.badge_type.name').toLowerCase();
  }.property('badge.badge_type.name'),

  showGrantCount: function() {
    return this.get('count') && this.get('count') > 1;
  }.property('count'),

  isIcon: function() {
    return this.get('badge.icon').match(/^fa-/);
  }.property('badge.icon')
});
