import Component from "@ember/component";
import Group from "discourse/models/group";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  allGroups: null,

  init() {
    this._super(...arguments);

    Group.findAll().then(groups => {
      this.set("allGroups", groups.filterBy("automatic", false));
    });
  },

  @action
  setGroupField(groupIds) {
    this.onChangeField(
      this.field,
      "group_id",
      groupIds && groupIds.firstObject
    );
  }
});
