import { ajax } from "discourse/lib/ajax";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  adminBackups: Ember.inject.controller(),
  status: Ember.computed.alias("adminBackups.model"),

  @computed
  localBackupStorage() {
    return this.siteSettings.backup_location === "local";
  },

  uploadLabel: function() {
    return I18n.t("admin.backups.upload.label");
  }.property(),

  restoreTitle: function() {
    if (!this.get("status.allowRestore")) {
      return "admin.backups.operations.restore.is_disabled";
    } else if (this.get("status.isOperationRunning")) {
      return "admin.backups.operations.is_running";
    } else {
      return "admin.backups.operations.restore.title";
    }
  }.property("status.{allowRestore,isOperationRunning}"),

  actions: {
    toggleReadOnlyMode() {
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
    },

    download(backup) {
      let link = backup.get("filename");
      ajax("/admin/backups/" + link, { type: "PUT" }).then(() => {
        bootbox.alert(I18n.t("admin.backups.operations.download.alert"));
      });
    }
  },

  _toggleReadOnlyMode(enable) {
    var site = this.site;
    ajax("/admin/backups/readonly", {
      type: "PUT",
      data: { enable: enable }
    }).then(() => {
      site.set("isReadOnly", enable);
    });
  }
});
