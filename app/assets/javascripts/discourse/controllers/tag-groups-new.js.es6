import Controller, { inject } from "@ember/controller";

export default Controller.extend({
  tagGroups: inject(),

  actions: {
    onSave() {
      const tagGroups = this.tagGroups.model;
      tagGroups.pushObject(this.model);

      this.transitionToRoute("tagGroups.edit", this.model);
    }
  }
});
