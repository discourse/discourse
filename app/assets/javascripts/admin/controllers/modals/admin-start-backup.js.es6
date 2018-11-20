import ModalFunctionality from "discourse/mixins/modal-functionality";
import Backup from "admin/models/backup";

export default Ember.Controller.extend(ModalFunctionality, {
  adminBackupsLogs: Ember.inject.controller(),

  _startBackup(withUploads) {
    this.currentUser.set("hideReadOnlyAlert", true);
    Backup.start(withUploads).then(() => {
      this.get("adminBackupsLogs.logs").clear();
      this.send("backupStarted");
    });
  },

  actions: {
    startBackup() {
      this._startBackup();
    },

    startBackupWithoutUpload() {
      this._startBackup(false);
    },

    cancel() {
      this.send("closeModal");
    }
  }
});
