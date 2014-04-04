Discourse.AdminBackupsLogsController = Ember.ArrayController.extend({
  needs: ["adminBackups"],
  status: Em.computed.alias("controllers.adminBackups")
});
