import EmberObject from "@ember/object";
import { not } from "@ember/object/computed";
import discourseComputed from "discourse/lib/decorators";

export default class BackupStatus extends EmberObject {
  @not("restoreEnabled") restoreDisabled;

  @discourseComputed("allowRestore", "isOperationRunning")
  restoreEnabled(allowRestore, isOperationRunning) {
    return allowRestore && !isOperationRunning;
  }
}
