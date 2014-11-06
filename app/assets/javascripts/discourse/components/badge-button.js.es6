export default Ember.Component.extend({
  tagName: 'span',
  classNameBindings: [':user-badge', 'badge.badgeTypeClassName'],
  title: Em.computed.alias('badge.displayDescription'),
  attributeBindings: ['data-badge-name', 'title'],
  'data-badge-name': Em.computed.alias('badge.name')
});
