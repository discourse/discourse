import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias, equal } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n, setting } from "discourse/lib/computed";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

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
  download(backup) {
    ajax(`/admin/backups/${backup.filename}`, { type: "PUT" }).then(() =>
      this.dialog.alert(I18n.t("admin.backups.operations.download.alert"))
    );
  }

  @discourseComputed("status.isOperationRunning")
  deleteTitle() {
    if (this.status.isOperationRunning) {
      return "admin.backups.operations.is_running";
    }

    return "admin.backups.operations.destroy.title";
  }
}
