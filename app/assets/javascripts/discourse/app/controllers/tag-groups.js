import Controller from "@ember/controller";
import { inject as service } from "@ember/service";

export default Controller.extend({
  router: service(),

  actions: {
    newTagGroup() {
      this.router.transitionTo("tagGroups.new");
    },
  },
});
