export default Ember.ObjectController.extend({
  noOperationIsRunning: Em.computed.not("model.isOperationRunning"),
  rollbackEnabled: Em.computed.and("model.canRollback", "model.restoreEnabled", "noOperationIsRunning"),
  rollbackDisabled: Em.computed.not("rollbackEnabled")
});
