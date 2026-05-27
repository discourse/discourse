import Controller, { inject as controller } from "@ember/controller";
import { computed, set } from "@ember/object";
import { autoTrackedArray } from "discourse/lib/tracked-tools";

export default class AdminBackupsLogsController extends Controller {
  @controller("admin.backups") adminBackups;

  @autoTrackedArray logs = [];

  @computed("adminBackups.model")
  get status() {
    return this.adminBackups?.model;
  }

  set status(value) {
    set(this, "adminBackups.model", value);
  }
}
