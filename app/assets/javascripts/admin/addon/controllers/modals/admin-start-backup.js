import { action } from "@ember/object";
import Controller, { inject as controller } from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default class AdminStartBackupController extends Controller.extend(
  ModalFunctionality
) {
  @controller adminBackupsLogs;

  @discourseComputed
  warningMessage() {
    // this is never shown here, but we may want to show different
    // messages in plugins
    return "";
  }

  @discourseComputed
  yesLabel() {
    return "yes_value";
  }

  @action
  startBackupWithUploads() {
    this.send("closeModal");
    this.send("startBackup", true);
  }

  @action
  startBackupWithoutUploads() {
    this.send("closeModal");
    this.send("startBackup", false);
  }

  @action
  cancel() {
    this.send("closeModal");
  }
}
