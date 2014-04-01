Discourse.AdminBackupsRoute = Discourse.Route.extend({

  LOG_CHANNEL: "/admin/backups/logs",

  activate: function() {
    Discourse.MessageBus.subscribe(this.LOG_CHANNEL, this._processLogMessage.bind(this));
  },

  _processLogMessage: function(log) {
    if (log.message === "[STARTED]") {
      this.controllerFor("adminBackups").set("isOperationRunning", true);
      this.controllerFor("adminBackupsLogs").clear();
    } else if (log.message === "[FAILED]") {
      this.controllerFor("adminBackups").set("isOperationRunning", false);
      bootbox.alert(I18n.t("admin.backups.operations.failed", { operation: log.operation }));
    } else if (log.message === "[SUCCESS]") {
      Discourse.User.currentProp("hideReadOnlyAlert", false);
      this.controllerFor("adminBackups").set("isOperationRunning", false);
      if (log.operation === "restore") {
        // redirect to homepage when the restore is done (session might be lost)
        window.location.pathname = Discourse.getURL("/");
      }
    } else {
      this.controllerFor("adminBackupsLogs").pushObject(Em.Object.create(log));
    }
  },

  model: function() {
    return PreloadStore.getAndRemove("operations_status", function() {
      return Discourse.ajax("/admin/backups/status.json");
    }).then(function (status) {
      return Discourse.BackupStatus.create({
        isOperationRunning: status.is_operation_running,
        canRollback: status.can_rollback
      });
    });
  },

  deactivate: function() {
    Discourse.MessageBus.unsubscribe(this.LOG_CHANNEL);
  },

  actions: {
    /**
      Starts a backup and redirect the user to the logs tab

      @method startBackup
    **/
    startBackup: function() {
      var self = this;
      bootbox.confirm(
        I18n.t("admin.backups.operations.backup.confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(confirmed) {
          if (confirmed) {
            Discourse.User.currentProp("hideReadOnlyAlert", true);
            Discourse.Backup.start().then(function() {
              self.controllerFor("adminBackupsLogs").clear();
              self.modelFor("adminBackups").set("isOperationRunning", true);
              self.transitionTo("admin.backups.logs");
            });
          }
        }
      );
    },

    /**
      Destroys a backup

      @method destroyBackup
      @param {Discourse.Backup} backup the backup to destroy
    **/
    destroyBackup: function(backup) {
      var self = this;
      bootbox.confirm(
        I18n.t("admin.backups.operations.destroy.confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(confirmed) {
          if (confirmed) {
            backup.destroy().then(function() {
              self.controllerFor("adminBackupsIndex").removeObject(backup);
            });
          }
        }
      );
    },

    /**
      Start a restore and redirect the user to the logs tab

      @method startRestore
      @param {Discourse.Backup} backup the backup to restore
    **/
    startRestore: function(backup) {
      var self = this;
      bootbox.confirm(
        I18n.t("admin.backups.operations.restore.confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(confirmed) {
          if (confirmed) {
            Discourse.User.currentProp("hideReadOnlyAlert", true);
            backup.restore().then(function() {
              self.controllerFor("adminBackupsLogs").clear();
              self.modelFor("adminBackups").set("isOperationRunning", true);
              self.transitionTo("admin.backups.logs");
            });
          }
        }
      );
    },

    /**
      Cancels the current operation

      @method cancelOperation
    **/
    cancelOperation: function() {
      var self = this;
      bootbox.confirm(
        I18n.t("admin.backups.operations.cancel.confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(confirmed) {
          if (confirmed) {
            Discourse.Backup.cancel().then(function() {
              self.controllerFor("adminBackups").set("isOperationRunning", false);
            });
          }
        }
      );
    },

    /**
      Rollback to previous working state

      @method rollback
    **/
    rollback: function() {
      bootbox.confirm(
        I18n.t("admin.backups.operations.rollback.confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(confirmed) {
          if (confirmed) { Discourse.Backup.rollback(); }
        }
      );
    },

    uploadSuccess: function(filename) {
      var self = this;
      bootbox.alert(I18n.t("admin.backups.upload.success", { filename: filename }), function() {
        Discourse.Backup.find().then(function (backups) {
          self.controllerFor("adminBackupsIndex").set("model", backups);
        });
      });
    },

    uploadError: function(filename, message) {
      bootbox.alert(I18n.t("admin.backups.upload.error", { filename: filename, message: message }));
    }
  }
});
