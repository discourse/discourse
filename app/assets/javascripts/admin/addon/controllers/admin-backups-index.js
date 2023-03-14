import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { alias, equal } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import { i18n, setting } from "discourse/lib/computed";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";

import discourseComputed from "discourse-common/utils/decorators";

export default class AdminBackupsIndexController extends Controller {
  @service dialog;
  @controller adminBackups;

  @alias("adminBackups.model") status;

  @i18n("admin.backups.upload.label") uploadLabel;

  @setting("backup_location") backupLocation;

  @equal("backupLocation", "local") localBackupStorage;

  @discourseComputed("status.allowRestore", "status.isOperationRunning")
  restoreTitle(allowRestore, isOperationRunning) {
    if (!allowRestore) {
      return "admin.backups.operations.restore.is_disabled";
    } else if (isOperationRunning) {
      return "admin.backups.operations.is_running";
    } else {
      return "admin.backups.operations.restore.title";
    }
  }

  @action
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
  }

  @action
  download(backup) {
    const link = backup.get("filename");
    ajax(`/admin/backups/${link}`, { type: "PUT" }).then(() =>
      this.dialog.alert(I18n.t("admin.backups.operations.download.alert"))
    );
  }

  _toggleReadOnlyMode(enable) {
    ajax("/admin/backups/readonly", {
      type: "PUT",
      data: { enable },
    }).then(() => this.site.set("isReadOnly", enable));
  }
}
