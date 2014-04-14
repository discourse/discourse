/**
  Data model for representing the status of backup/restore

  @class BackupStatus
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.BackupStatus = Discourse.Model.extend({

  restoreDisabled: Em.computed.not("restoreEnabled"),

  restoreEnabled: function() {
    return Discourse.SiteSettings.allow_restore && !this.get("isOperationRunning");
  }.property("isOperationRunning")
});
