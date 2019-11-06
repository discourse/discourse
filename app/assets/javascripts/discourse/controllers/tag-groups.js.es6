import Controller from "@ember/controller";

export default Controller.extend({
  actions: {
    newTagGroup() {
      this.transitionToRoute("tagGroups.new");
    }
  }
});
