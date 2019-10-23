import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { setting, i18n } from "discourse/lib/computed";

export default Controller.extend({
  adminBackups: Ember.inject.controller(),
  status: Ember.computed.alias("adminBackups.model"),
  uploadLabel: i18n("admin.backups.upload.label"),
  backupLocation: setting("backup_location"),
  localBackupStorage: Ember.computed.equal("backupLocation", "local"),

  @computed("status.allowRestore", "status.isOperationRunning")
  restoreTitle(allowRestore, isOperationRunning) {
    if (!allowRestore) {
      return "admin.backups.operations.restore.is_disabled";
    } else if (isOperationRunning) {
      return "admin.backups.operations.is_running";
    } else {
      return "admin.backups.operations.restore.title";
    }
  },

  actions: {
    toggleReadOnlyMode() {
      if (!this.site.get("isReadOnly")) {
        bootbox.confirm(
          I18n.t("admin.backups.read_only.enable.confirm"),
          I18n.t("no_value"),
          I18n.t("yes_value"),
          confirmed => {
            if (confirmed) {
              this.set("currentUser.hideReadOnlyAlert", true);
              this._toggleReadOnlyMode(true);
            }
          }
        );
      } else {
        this._toggleReadOnlyMode(false);
      }
    },

    download(backup) {
      const link = backup.get("filename");
      ajax(`/admin/backups/${link}`, { type: "PUT" }).then(() =>
        bootbox.alert(I18n.t("admin.backups.operations.download.alert"))
      );
    }
  },

  _toggleReadOnlyMode(enable) {
    ajax("/admin/backups/readonly", {
      type: "PUT",
      data: { enable }
    }).then(() => this.site.set("isReadOnly", enable));
  }
});
