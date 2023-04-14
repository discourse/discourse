import Controller, { inject as controller } from "@ember/controller";

export default Controller.extend({
  tagGroups: controller(),

  actions: {
    onDestroy() {
      const tagGroups = this.tagGroups.model;
      tagGroups.removeObject(this.model);

      this.transitionToRoute("tagGroups.index");
    },
  },
});
