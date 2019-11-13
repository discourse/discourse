import discourseComputed from "discourse-common/utils/decorators";
import { not } from "@ember/object/computed";

export default Discourse.Model.extend({
  restoreDisabled: not("restoreEnabled"),

  @discourseComputed("allowRestore", "isOperationRunning")
  restoreEnabled(allowRestore, isOperationRunning) {
    return allowRestore && !isOperationRunning;
  }
});
