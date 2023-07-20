import { and, not } from "@ember/object/computed";
import Controller from "@ember/controller";
export default class AdminBackupsController extends Controller {
  @not("model.isOperationRunning") noOperationIsRunning;
  @not("rollbackEnabled") rollbackDisabled;
  @and("model.canRollback", "model.restoreEnabled", "noOperationIsRunning")
  rollbackEnabled;
}
