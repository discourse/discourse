import Controller from "@ember/controller";
import TagGroup from "discourse/models/tag-group";

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
      const newTagGroup = TagGroup.create({
        id: "new",
        name: I18n.t("tagging.groups.new_name")
      });
      this.model.pushObject(newTagGroup);
      this.send("selectTagGroup", newTagGroup);
    }
  }
});
