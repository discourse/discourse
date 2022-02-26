import BaseField from "./da-base-field";
import Group from "discourse/models/group";
import { action } from "@ember/object";

export default BaseField.extend({
  allGroups: null,

  init() {
    this._super(...arguments);

    Group.findAll().then((groups) => {
      this.set("allGroups", groups);
    });
  },

  @action
  setGroupField(groupIds) {
    this.onChangeField(this.field, "value", groupIds && groupIds.firstObject);
  },
});
