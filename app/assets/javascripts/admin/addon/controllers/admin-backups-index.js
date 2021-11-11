import Controller, { inject as controller } from "@ember/controller";
import { alias, equal } from "@ember/object/computed";
import { i18n, setting } from "discourse/lib/computed";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  adminBackups: controller(),
  status: alias("adminBackups.model"),
  uploadLabel: i18n("admin.backups.upload.label"),
  backupLocation: setting("backup_location"),
  localBackupStorage: equal("backupLocation", "local"),
  enableExperimentalBackupUploader: setting(
    "enable_experimental_backup_uploader"
  ),

  @discourseComputed("status.allowRestore", "status.isOperationRunning")
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
          (confirmed) => {
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
    },
  },

  _toggleReadOnlyMode(enable) {
    ajax("/admin/backups/readonly", {
      type: "PUT",
      data: { enable },
    }).then(() => this.site.set("isReadOnly", enable));
  },
});
