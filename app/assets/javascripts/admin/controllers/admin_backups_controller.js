Discourse.AdminBackupsController = Ember.ObjectController.extend({
  noOperationIsRunning: Em.computed.not("isOperationRunning"),
  rollbackEnabled: Em.computed.and("canRollback", "restoreEnabled", "noOperationIsRunning"),
  rollbackDisabled: Em.computed.not("rollbackEnabled")
});
