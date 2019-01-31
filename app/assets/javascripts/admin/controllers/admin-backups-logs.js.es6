export default Ember.Controller.extend({
  logs: [],
  adminBackups: Ember.inject.controller(),
  status: Ember.computed.alias("adminBackups.model")
});
