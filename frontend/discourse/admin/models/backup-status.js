import EmberObject, { computed } from "@ember/object";
import { not } from "@ember/object/computed";

export default class BackupStatus extends EmberObject {
  @not("restoreEnabled") restoreDisabled;

  @computed("allowRestore", "isOperationRunning")
  get restoreEnabled() {
    return this.allowRestore && !this.isOperationRunning;
  }
}
