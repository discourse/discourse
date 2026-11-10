import Controller, { inject as controller } from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { trackedArray } from "@ember/reactive/collections";
import { service } from "@ember/service";
import Backup from "discourse/admin/models/backup";
import { ajax } from "discourse/lib/ajax";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";

export default class AdminBackupsIndexController extends Controller {
  @service dialog;
  @controller("admin.backups") adminBackups;

  // Owned here so an upload outlives the uploader, which leaving the tab or closing the mobile
  // actions menu destroys
  uppyUpload = this.#createUppyUpload();

  @computed("adminBackups.model")
  get status() {
    return this.adminBackups?.model;
  }

  set status(value) {
    set(this, "adminBackups.model", value);
  }

  @dependentKeyCompat
  get uploadLabel() {
    return i18n(`admin.backups.upload.label`);
  }

  @computed("siteSettings.backup_location")
  get backupLocation() {
    return this.siteSettings.backup_location;
  }

  @computed("backupLocation")
  get localBackupStorage() {
    return this.backupLocation === "local";
  }

  get restoreSettingsUrl() {
    return getURL("/admin/backups/settings?filter=allow_restore");
  }

  @computed("status.allowRestore", "status.isOperationRunning")
  get restoreTitle() {
    if (!this.status?.allowRestore) {
      return "admin.backups.operations.restore.is_disabled_title";
    } else if (this.status?.isOperationRunning) {
      return "admin.backups.operations.is_running";
    } else {
      return "admin.backups.operations.restore.title";
    }
  }

  @computed("status.isOperationRunning")
  get deleteTitle() {
    if (this.status.isOperationRunning) {
      return "admin.backups.operations.is_running";
    }

    return "admin.backups.operations.destroy.title";
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

  #createUppyUpload() {
    const backups = this;

    return new UppyUpload(backups, {
      id: "uppy-backup-uploader",
      type: "backup",
      uploadRootPath: "/admin/backups",
      uploadUrl: "/admin/backups/upload",
      validateUploadedFilesOptions: { skipValidation: true },

      // local backups
      get useChunkedUploads() {
        return backups.localBackupStorage;
      },

      // direct s3 backups
      useMultipartUploadsIfAvailable: true,

      uploadDone: ({ file_name }) => {
        if (backups.localBackupStorage) {
          backups.dialog.alert(
            i18n("admin.backups.upload.success", { filename: file_name })
          );
        } else {
          backups.#refreshBackups();
        }
      },
    });
  }

  async #refreshBackups() {
    try {
      const backups = await Backup.find();
      this.model = trackedArray(backups.map((backup) => Backup.create(backup)));
    } catch (error) {
      this.dialog.alert(
        i18n("admin.backups.backup_storage_error", {
          error_message: extractError(error),
        })
      );
    }
  }
}
