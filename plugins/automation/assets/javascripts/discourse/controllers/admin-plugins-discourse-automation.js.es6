import { inject as service } from "@ember/service";
import { action, computed } from "@ember/object";

export default Ember.Controller.extend({
  @action
  newAutomation() {
    this.transitionToRoute("adminPlugins.discourse-automation.new");
  },

  router: service(),

  showNewAutomation: computed("router.currentRouteName", function () {
    return (
      this.router.currentRouteName === "adminPlugins.discourse-automation.index"
    );
  }),
});
