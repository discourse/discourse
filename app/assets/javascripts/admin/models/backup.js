/**
  Data model for representing a backup

  @class Backup
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Backup = Discourse.Model.extend({

  /**
    Destroys the current backup

    @method destroy
    @returns {Promise} a promise that resolves when the backup has been destroyed
  **/
  destroy: function() {
    return Discourse.ajax("/admin/backups/" + this.get("filename"), { type: "DELETE" });
  },

  /**
    Starts the restoration of the current backup

    @method restore
    @returns {Promise} a promise that resolves when the backup has started being restored
  **/
  restore: function() {
    return Discourse.ajax("/admin/backups/" + this.get("filename") + "/restore", { type: "POST" });
  }

});

Discourse.Backup.reopenClass({

  /**
    Finds a list of backups

    @method find
    @returns {Promise} a promise that resolves to the array of {Discourse.Backup} backup
  **/
  find: function() {
    return PreloadStore.getAndRemove("backups", function() {
      return Discourse.ajax("/admin/backups.json");
    }).then(function(backups) {
      return backups.map(function (backup) { return Discourse.Backup.create(backup); });
    });
  },

  /**
    Starts a backup

    @method start
    @returns {Promise} a promise that resolves when the backup has started
  **/
  start: function() {
    return Discourse.ajax("/admin/backups", { type: "POST" }).then(function(result) {
      if (!result.success) { bootbox.alert(result.message); }
    });
  },

  /**
    Cancels a backup

    @method cancel
    @returns {Promise} a promise that resolves when the backup has been cancelled
  **/
  cancel: function() {
    return Discourse.ajax("/admin/backups/cancel.json").then(function(result) {
      if (!result.success) { bootbox.alert(result.message); }
    });
  },

  /**
    Rollbacks the database to the previous working state

    @method rollback
    @returns {Promise} a promise that resolves when the rollback is done
  **/
  rollback: function() {
    return Discourse.ajax("/admin/backups/rollback.json").then(function(result) {
      if (!result.success) {
        bootbox.alert(result.message);
      } else {
        // redirect to homepage (session might be lost)
        window.location.pathname = Discourse.getURL("/");
      }
    });
  }
});
