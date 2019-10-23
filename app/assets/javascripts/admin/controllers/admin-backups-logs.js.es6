import Controller from "@ember/controller";
export default Controller.extend({
  adminBackups: Ember.inject.controller(),
  status: Ember.computed.alias("adminBackups.model"),

  init() {
    this._super(...arguments);

    this.logs = [];
  }
});
