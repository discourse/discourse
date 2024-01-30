import Controller from "@ember/controller";
import { and, not } from "@ember/object/computed";
export default class AdminBackupsController extends Controller {
  @not("model.isOperationRunning") noOperationIsRunning;
  @not("rollbackEnabled") rollbackDisabled;
  @and("model.canRollback", "model.restoreEnabled", "noOperationIsRunning")
  rollbackEnabled;
}
