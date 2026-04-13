import EmberObject, { computed } from "@ember/object";

export default class BackupStatus extends EmberObject {
  @computed("restoreEnabled")
  get restoreDisabled() {
    return !this.restoreEnabled;
  }

  @computed("allowRestore", "isOperationRunning")
  get restoreEnabled() {
    return this.allowRestore && !this.isOperationRunning;
  }
}
