import { not } from "@ember/object/computed";
import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default class BackupStatus extends EmberObject {
  @not("restoreEnabled") restoreDisabled;

  @discourseComputed("allowRestore", "isOperationRunning")
  restoreEnabled(allowRestore, isOperationRunning) {
    return allowRestore && !isOperationRunning;
  }
}
