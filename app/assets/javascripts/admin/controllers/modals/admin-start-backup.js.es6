import ModalFunctionality from "discourse/mixins/modal-functionality";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend(ModalFunctionality, {
  adminBackupsLogs: Ember.inject.controller(),

  @computed("adminBackupsLogs.status.{s3Uploads,strictBackup}")
  withoutUploadsButtonLabel(status) {
    const { s3Uploads, strictBackup } = status;
    let key = "admin.backups.operations.backup.";
    if (!s3Uploads) {
      key += "without_local_uploads";
    } else if (strictBackup) {
      key += "without_uploads_strict";
    } else {
      key += "without_s3_uploads";
    }
    return key;
  },

  @computed("adminBackupsLogs.status.{s3Uploads,strictBackup}")
  withUploadsButtonLabel(status) {
    const { s3Uploads, strictBackup } = status;
    if (!s3Uploads) {
      return "yes_value";
    } else if (strictBackup) {
      return "admin.backups.operations.backup.with_s3_uploads_strict";
    } else {
      return "admin.backups.operations.backup.with_s3_uploads";
    }
  },

  actions: {
    startBackupWithUploads() {
      this.send("closeModal");
      this.send("startBackup", true);
    },

    startBackupWithoutUploads() {
      this.send("closeModal");
      this.send("startBackup", false);
    },

    cancel() {
      this.send("closeModal");
    }
  }
});
