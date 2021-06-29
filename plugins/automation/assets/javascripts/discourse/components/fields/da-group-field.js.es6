import BaseField from "./da-base-field";
import Group from "discourse/models/group";
import { action } from "@ember/object";
import { reads } from "@ember/object/computed";

export default BaseField.extend({
  allGroups: null,

  init() {
    this._super(...arguments);

    Group.findAll().then(groups => {
      this.set("allGroups", groups);
    });
  },

  fieldValue: reads("field.metadata.group_id"),

  @action
  setGroupField(groupIds) {
    this.onChangeField(
      this.field,
      "group_id",
      groupIds && groupIds.firstObject
    );
  }
});
