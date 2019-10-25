import Controller from "@ember/controller";

export default Controller.extend({
  actions: {
    selectTagGroup(tagGroup) {
      if (this.selectedItem) {
        this.selectedItem.set("selected", false);
      }
      this.set("selectedItem", tagGroup);
      tagGroup.set("selected", true);
      tagGroup.set("savingStatus", null);
      this.transitionToRoute("tagGroups.show", tagGroup);
    },

    newTagGroup() {
      this.transitionToRoute("tagGroups.new");
    }
  }
});
