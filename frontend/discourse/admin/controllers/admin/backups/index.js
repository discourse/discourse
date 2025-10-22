import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias, equal } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { computedI18n, setting } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class AdminBackupsIndexController extends Controller {
  @service dialog;
  @controller("admin.backups") adminBackups;

  @alias("adminBackups.model") status;
  @computedI18n("admin.backups.upload.label") uploadLabel;
  @setting("backup_location") backupLocation;
  @equal("backupLocation", "local") localBackupStorage;

  get restoreSettingsUrl() {
    return getURL("/admin/backups/settings?filter=allow_restore");
  }

  @discourseComputed("status.allowRestore", "status.isOperationRunning")
  restoreTitle(allowRestore, isOperationRunning) {
    if (!allowRestore) {
      return "admin.backups.operations.restore.is_disabled_title";
    } else if (isOperationRunning) {
      return "admin.backups.operations.is_running";
    } else {
      return "admin.backups.operations.restore.title";
    }
  }

  @action
  async download(backup) {
    try {
      await ajax(`/admin/backups/${backup.filename}`, { type: "PUT" });
      this.dialog.alert(i18n("admin.backups.operations.download.alert"));
    } catch (err) {
      popupAjaxError(err);
    }
  }

  @discourseComputed("status.isOperationRunning")
  deleteTitle() {
    if (this.status.isOperationRunning) {
      return "admin.backups.operations.is_running";
    }

    return "admin.backups.operations.destroy.title";
  }
}
