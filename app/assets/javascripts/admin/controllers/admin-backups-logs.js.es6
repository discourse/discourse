import { alias } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
export default Controller.extend({
  adminBackups: inject(),
  status: alias("adminBackups.model"),

  init() {
    this._super(...arguments);

    this.logs = [];
  }
});
