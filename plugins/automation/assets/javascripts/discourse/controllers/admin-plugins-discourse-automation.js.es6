import { action } from "@ember/object";

export default Ember.Controller.extend({
  @action
  newAutomation() {
    this.transitionToRoute("adminPlugins.discourse-automation.new");
  },
});
