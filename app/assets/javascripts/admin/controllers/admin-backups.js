import { not, and } from "@ember/object/computed";
import Controller from "@ember/controller";
export default Controller.extend({
  noOperationIsRunning: not("model.isOperationRunning"),
  rollbackEnabled: and(
    "model.canRollback",
    "model.restoreEnabled",
    "noOperationIsRunning"
  ),
  rollbackDisabled: not("rollbackEnabled")
});
