import { alias } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";

export default Controller.extend({
  adminBackups: controller(),
  status: alias("adminBackups.model"),

  init() {
    this._super(...arguments);

    this.logs = [];
  }
});
