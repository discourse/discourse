import Controller, { inject as controller } from "@ember/controller";
import { alias } from "@ember/object/computed";

export default class AdminBackupsLogsController extends Controller {
  @controller adminBackups;

  @alias("adminBackups.model") status;

  logs = [];
}
