export default Ember.ArrayController.extend({
  needs: ["adminBackups"],
  status: Em.computed.alias("controllers.adminBackups"),

  uploadText: function() { return I18n.t("admin.backups.upload.text"); }.property(),

  readOnlyModeDisabled: Em.computed.alias("status.isOperationRunning"),

  restoreDisabled: Em.computed.alias("status.restoreDisabled"),

  restoreTitle: function() {
    if (!this.get('status.allowRestore')) {
      return I18n.t("admin.backups.operations.restore.is_disabled");
    } else if (this.get("status.isOperationRunning")) {
      return I18n.t("admin.backups.operation_already_running");
    } else {
      return I18n.t("admin.backups.operations.restore.title");
    }
  }.property("status.isOperationRunning"),

  destroyDisabled: Em.computed.alias("status.isOperationRunning"),

  destroyTitle: function() {
    if (this.get("status.isOperationRunning")) {
      return I18n.t("admin.backups.operation_already_running");
    } else {
      return I18n.t("admin.backups.operations.destroy.title");
    }
  }.property("status.isOperationRunning"),

  readOnlyModeTitle: function() { return this._readOnlyModeI18n("title"); }.property("site.isReadOnly"),
  readOnlyModeText: function() { return this._readOnlyModeI18n("text"); }.property("site.isReadOnly"),

  _readOnlyModeI18n: function(value) {
    var action = this.site.get("isReadOnly") ? "disable" : "enable";
    return I18n.t("admin.backups.read_only." + action + "." + value);
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
