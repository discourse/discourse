import { inject } from "@ember/controller";
import Controller from "@ember/controller";
export default Controller.extend({
  adminBackups: inject(),
  status: Ember.computed.alias("adminBackups.model"),

  init() {
    this._super(...arguments);

    this.logs = [];
  }
});
