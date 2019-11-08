import discourseComputed from "discourse-common/utils/decorators";
import { not } from "@ember/object/computed";
import EmberObject from "@ember/object";

export default EmberObject.extend({
  restoreDisabled: not("restoreEnabled"),

  @discourseComputed("allowRestore", "isOperationRunning")
  restoreEnabled(allowRestore, isOperationRunning) {
    return allowRestore && !isOperationRunning;
  }
});
