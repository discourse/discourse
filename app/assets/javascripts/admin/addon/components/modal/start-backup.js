import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class StartBackup extends Component {
  // this is never shown here, but we may want to show different
  // messages in plugins
  get warningMessage() {
    return "";
  }

  @action
  startBackupWithUploads() {
    this.args.model.startBackup(true);
    this.args.closeModal();
  }

  @action
  startBackupWithoutUploads() {
    this.args.model.startBackup(false);
    this.args.closeModal();
  }
}
