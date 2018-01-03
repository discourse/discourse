export default Ember.Component.extend({
  classNames: ['user-stat'],
  type: 'number',
  isNumber: Ember.computed.equal('type', 'number')
});
