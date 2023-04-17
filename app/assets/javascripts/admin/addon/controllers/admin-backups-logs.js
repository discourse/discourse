import { alias } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";

export default class AdminBackupsLogsController extends Controller {
  @controller adminBackups;

  @alias("adminBackups.model") status;

  logs = [];
}
