export default Ember.Controller.extend({
  discovery: Ember.inject.controller(),
  discoveryTopics: Ember.inject.controller('discovery/topics'),
});
