import { action } from "@ember/object";

export default Ember.Controller.extend({
  @action
  editAutomation(automation) {
    this.transitionToRoute(
      "adminPlugins.discourse-automation.edit",
      automation.id
    );
  },
});
