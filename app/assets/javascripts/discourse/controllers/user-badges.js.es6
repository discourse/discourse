export default Ember.ArrayController.extend({
  sortProperties: ['grouping_position', 'badge.badge_type.sort_order', 'badge.name', 'badge.id']
});
