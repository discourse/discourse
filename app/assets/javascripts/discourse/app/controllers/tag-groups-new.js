import Controller, { inject as controller } from "@ember/controller";

export default Controller.extend({
  tagGroups: controller(),

  actions: {
    onSave() {
      const tagGroups = this.tagGroups.model;
      tagGroups.pushObject(this.model);

      this.transitionToRoute("tagGroups.index");
    },
  },
});
