import { inject } from "@ember/controller";
import Controller from "@ember/controller";

export default Controller.extend({
  tagGroups: inject(),

  actions: {
    onDestroy() {
      let tagGroups = this.tagGroups.model;
      tagGroups.removeObject(this.model);

      this.transitionToRoute("tagGroups.index");
    }
  }
});
