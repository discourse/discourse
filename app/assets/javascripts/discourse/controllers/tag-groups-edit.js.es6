import { inject } from "@ember/controller";
import Controller from "@ember/controller";

export default Controller.extend({
  tagGroups: inject(),

  actions: {
    onDestroy() {
      const tagGroups = this.tagGroups.model;
      tagGroups.removeObject(this.model);

      this.transitionToRoute("tagGroups.index");
    }
  }
});
