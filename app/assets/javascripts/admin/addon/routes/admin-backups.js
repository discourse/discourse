import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";
import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import StartBackupModal from "admin/components/modal/start-backup";
import Backup from "admin/models/backup";
import BackupStatus from "admin/models/backup-status";

const LOG_CHANNEL = "/admin/backups/logs";

export default class AdminBackupsRoute extends DiscourseRoute {
  @service currentUser;
  @service dialog;
  @service router;
  @service messageBus;
  @service modal;

  titleToken() {
    return i18n("admin.backups.title");
  }

  activate() {
    this.messageBus.subscribe(LOG_CHANNEL, this.onMessage);
  }

  deactivate() {
    this.messageBus.unsubscribe(LOG_CHANNEL, this.onMessage);
  }

  async model() {
    const status = await PreloadStore.getAndRemove("operations_status", () =>
      ajax("/admin/backups/status.json")
    );

    return BackupStatus.create({
      isOperationRunning: status.is_operation_running,
      canRollback: status.can_rollback,
      allowRestore: status.allow_restore,
    });
  }

  @bind
  onMessage(log) {
    if (log.message === "[STARTED]") {
      this.currentUser.set("hideReadOnlyAlert", true);
      this.controllerFor("adminBackups").set("model.isOperationRunning", true);
      this.controllerFor("adminBackupsLogs").get("logs").clear();
    } else if (log.message === "[FAILED]") {
      this.controllerFor("adminBackups").set("model.isOperationRunning", false);
      this.dialog.alert(
        i18n("admin.backups.operations.failed", {
          operation: log.operation,
        })
      );
    } else if (log.message === "[SUCCESS]") {
      this.currentUser.set("hideReadOnlyAlert", false);
      this.controllerFor("adminBackups").set("model.isOperationRunning", false);
      if (log.operation === "restore") {
        // redirect to homepage when the restore is done (session might be lost)
        window.location = getURL("/");
      }
    } else {
      this.controllerFor("adminBackupsLogs")
        .get("logs")
        .pushObject(EmberObject.create(log));
    }
  }

  @action
  showStartBackupModal() {
    this.modal.show(StartBackupModal, {
      model: { startBackup: this.startBackup },
    });
  }

  @action
  startBackup(withUploads) {
    this.router.transitionTo("admin.backups.logs");
    Backup.start(withUploads).then((result) => {
      if (!result.success) {
        this.dialog.alert(result.message);
      }
    });
  }

  @action
  destroyBackup(backup) {
    return this.dialog.yesNoConfirm({
      message: i18n("admin.backups.operations.destroy.confirm"),
      didConfirm: () => {
        backup
          .destroy()
          .then(() =>
            this.controllerFor("adminBackupsIndex")
              .get("model")
              .removeObject(backup)
          );
      },
    });
  }

  @action
  startRestore(backup) {
    this.dialog.yesNoConfirm({
      message: i18n("admin.backups.operations.restore.confirm"),
      didConfirm: () => {
        this.router.transitionTo("admin.backups.logs");
        backup.restore();
      },
    });
  }

  @action
  cancelOperation() {
    this.dialog.yesNoConfirm({
      message: i18n("admin.backups.operations.cancel.confirm"),
      didConfirm: () => {
        Backup.cancel().then(() => {
          this.controllerFor("adminBackups").set(
            "model.isOperationRunning",
            false
          );
        });
      },
    });
  }

  @action
  rollback() {
    return this.dialog.yesNoConfirm({
      message: i18n("admin.backups.operations.rollback.confirm"),
      didConfirm: () => {
        Backup.rollback().then((result) => {
          if (!result.success) {
            this.dialog.alert(result.message);
          } else {
            // redirect to homepage (session might be lost)
            window.location = getURL("/");
          }
        });
      },
    });
  }

  @action
  uploadSuccess(filename) {
    this.dialog.alert(i18n("admin.backups.upload.success", { filename }));
  }

  @action
  uploadError(filename, message) {
    this.dialog.alert(
      i18n("admin.backups.upload.error", { filename, message })
    );
  }

  @action
  remoteUploadSuccess() {
    Backup.find()
      .then((backups) => backups.map((backup) => Backup.create(backup)))
      .then((backups) => {
        this.controllerFor("adminBackupsIndex").set(
          "model",
          backups.map((backup) => Backup.create(backup))
        );
      })
      .catch((error) => {
        this.dialog.alert(
          i18n("admin.backups.backup_storage_error", {
            error_message: extractError(error),
          })
        );
        return [];
      });
  }
}
