import Controller, { inject as controller } from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  adminBackupsLogs: controller(),

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
