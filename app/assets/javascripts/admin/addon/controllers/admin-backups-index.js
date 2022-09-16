import Controller, { inject as controller } from "@ember/controller";
import { alias, equal } from "@ember/object/computed";
import { i18n, setting } from "discourse/lib/computed";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";

import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Controller.extend({
  adminBackups: controller(),
  dialog: service(),
  status: alias("adminBackups.model"),
  uploadLabel: i18n("admin.backups.upload.label"),
  backupLocation: setting("backup_location"),
  localBackupStorage: equal("backupLocation", "local"),

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
        this.dialog.yesNoConfirm({
          message: I18n.t("admin.backups.read_only.enable.confirm"),
          didConfirm: () => {
            this.set("currentUser.hideReadOnlyAlert", true);
            this._toggleReadOnlyMode(true);
          },
        });
      } else {
        this._toggleReadOnlyMode(false);
      }
    },

    download(backup) {
      const link = backup.get("filename");
      ajax(`/admin/backups/${link}`, { type: "PUT" }).then(() =>
        this.dialog.alert(I18n.t("admin.backups.operations.download.alert"))
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
