export default Ember.Controller.extend({
  logs: [],
  adminBackups: Ember.inject.controller(),
  status: Em.computed.alias("adminBackups.model")
});
