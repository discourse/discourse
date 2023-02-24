import { inject as controller } from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import Modal from "discourse/controllers/modal";

export default Modal.extend({
  adminBackupsLogs: controller(),

  @discourseComputed
  warningMessage() {
    // this is never shown here, but we may want to show different
    // messages in plugins
    return "";
  },

  @discourseComputed
  yesLabel() {
    return "yes_value";
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
    },
  },
});
