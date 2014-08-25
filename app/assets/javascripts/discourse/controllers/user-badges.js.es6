export default Ember.ArrayController.extend({
  sortProperties: ['grouping_position', 'badge.badgeType.id', 'badge.name', 'badge.id']
});
