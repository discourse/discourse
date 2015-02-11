export default Ember.ArrayController.extend({
  needs: ["adminBackups"],
  status: Em.computed.alias("controllers.adminBackups"),

  uploadText: function() { return I18n.t("admin.backups.upload.text"); }.property(),

  readOnlyModeDisabled: Em.computed.alias("status.isOperationRunning"),

  restoreDisabled: Em.computed.alias("status.restoreDisabled"),

  restoreTitleKey: function() {
    if (!this.get('status.allowRestore')) {
      return "admin.backups.operations.restore.is_disabled";
    } else if (this.get("status.isOperationRunning")) {
      return "admin.backups.operation_already_running";
    } else {
      return "admin.backups.operations.restore.title";
    }
  }.property("status.isOperationRunning"),

  destroyDisabled: Em.computed.alias("status.isOperationRunning"),

  destroyTitleKey: function() {
    if (this.get("status.isOperationRunning")) {
      return "admin.backups.operation_already_running";
    } else {
      return "admin.backups.operations.destroy.title";
    }
  }.property("status.isOperationRunning"),

  readOnlyModeTitleKey: function() { return this._readOnlyModeI18nKey("title"); }.property("site.isReadOnly"),
  readOnlyModeTextKey: function() { return this._readOnlyModeI18nKey("text"); }.property("site.isReadOnly"),

  _readOnlyModeI18nKey: function(value) {
    var action = this.site.get("isReadOnly") ? "disable" : "enable";
    return "admin.backups.read_only." + action + "." + value;
  },

  actions: {

    /**
      Toggle read-only mode

      @method toggleReadOnlyMode
    **/
    toggleReadOnlyMode: function() {
      var self = this;
      if (!this.site.get("isReadOnly")) {
        bootbox.confirm(
          I18n.t("admin.backups.read_only.enable.confirm"),
          I18n.t("no_value"),
          I18n.t("yes_value"),
          function(confirmed) {
            if (confirmed) {
              Discourse.User.currentProp("hideReadOnlyAlert", true);
              self._toggleReadOnlyMode(true);
            }
          }
        );
      } else {
        this._toggleReadOnlyMode(false);
      }
    }

  },

  _toggleReadOnlyMode: function(enable) {
    var site = this.site;
    Discourse.ajax("/admin/backups/readonly", {
      type: "PUT",
      data: { enable: enable }
    }).then(function() {
      site.set("isReadOnly", enable);
    });
  }
});
