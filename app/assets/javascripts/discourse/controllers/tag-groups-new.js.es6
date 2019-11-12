import Controller from "@ember/controller";

export default Controller.extend({
  tagGroups: Ember.inject.controller(),

  actions: {
    onSave() {
      const tagGroups = this.tagGroups.model;
      tagGroups.pushObject(this.model);

      this.transitionToRoute("tagGroups.edit", this.model);
    }
  }
});
