Discourse.BackupStatus = Discourse.Model.extend({

  restoreDisabled: Em.computed.not("restoreEnabled"),

  restoreEnabled: function() {
    return this.get('allowRestore') && !this.get("isOperationRunning");
  }.property("isOperationRunning", "allowRestore")

});
