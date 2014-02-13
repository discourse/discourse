Discourse.AdminBackupsIndexController = Ember.ArrayController.extend({
  needs: ["adminBackups"],
  status: Em.computed.alias("controllers.adminBackups"),

  rollbackDisabled: Em.computed.not("rollbackEnabled"),

  rollbackEnabled: function() {
    return this.get("status.canRollback") && this.get("restoreEnabled");
  }.property("status.canRollback", "restoreEnabled"),

  restoreDisabled: Em.computed.not("restoreEnabled"),

  restoreEnabled: function() {
    return Discourse.SiteSettings.allow_import && !this.get("status.isOperationRunning");
  }.property("status.isOperationRunning"),

  restoreTitle: function() {
    if (!Discourse.SiteSettings.allow_import) {
      return I18n.t("admin.backups.operations.restore.is_disabled");
    } else if (this.get("status.isOperationRunning")) {
      return I18n.t("admin.backups.operation_already_running");
    } else {
      return I18n.t("admin.backups.operations.restore.title");
    }
  }.property("status.isOperationRunning"),

  destroyTitle: function() {
    if (this.get("status.isOperationRunning")) {
      return I18n.t("admin.backups.operation_already_running");
    } else {
      return I18n.t("admin.backups.operations.destroy.title");
    }
  }.property("status.isOperationRunning"),

  readOnlyModeTitle: function() { return this._readOnlyModeI18n("title"); }.property("Discourse.isReadOnly"),
  readOnlyModeText: function() { return this._readOnlyModeI18n("text"); }.property("Discourse.isReadOnly"),

  _readOnlyModeI18n: function(value) {
    var action = Discourse.get("isReadOnly") ? "disable" : "enable";
    return I18n.t("admin.backups.read_only." + action + "." + value);
  },

  actions: {

    /**
      Toggle read-only mode

      @method toggleReadOnlyMode
    **/
    toggleReadOnlyMode: function() {
      var self = this;
      if (!Discourse.get("isReadOnly")) {
        bootbox.confirm(
          I18n.t("admin.backups.read_only.enable.confirm"),
          I18n.t("no_value"),
          I18n.t("yes_value"),
          function(confirmed) {
            if (confirmed) { self._toggleReadOnlyMode(true); }
          }
        );
      } else {
        this._toggleReadOnlyMode(false);
      }
    },

  },

  _toggleReadOnlyMode: function(enable) {
    Discourse.ajax("/admin/backups/readonly", {
      type: "PUT",
      data: { enable: enable }
    }).then(function() {
      Discourse.set("isReadOnly", enable);
    });
  },

});
