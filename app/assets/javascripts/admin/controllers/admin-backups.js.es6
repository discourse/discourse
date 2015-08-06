export default Ember.ObjectController.extend({
  noOperationIsRunning: Ember.computed.not("model.isOperationRunning"),
  rollbackEnabled: Ember.computed.and("model.canRollback", "model.restoreEnabled", "noOperationIsRunning"),
  rollbackDisabled: Ember.computed.not("rollbackEnabled")
});
