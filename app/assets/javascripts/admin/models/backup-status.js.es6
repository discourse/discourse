import { not } from "@ember/object/computed";
import computed from "ember-addons/ember-computed-decorators";

export default Discourse.Model.extend({
  restoreDisabled: not("restoreEnabled"),

  @computed("allowRestore", "isOperationRunning")
  restoreEnabled(allowRestore, isOperationRunning) {
    return allowRestore && !isOperationRunning;
  }
});
