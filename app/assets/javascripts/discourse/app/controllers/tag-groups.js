import Controller from "@ember/controller";
import { service } from "@ember/service";

export default Controller.extend({
  router: service(),

  actions: {
    newTagGroup() {
      this.router.transitionTo("tagGroups.new");
    },
  },
});
