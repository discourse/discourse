import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class StartBackup extends Component {
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
