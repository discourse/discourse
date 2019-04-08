export default Ember.Component.extend({
  showUsername: Ember.computed.gte("index", 1)
});
