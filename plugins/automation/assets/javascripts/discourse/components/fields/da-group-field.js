import BaseField from "./da-base-field";
import Group from "discourse/models/group";
import { action } from "@ember/object";

export default class GroupField extends BaseField {
  allGroups = null;

  init() {
    super.init(...arguments);

    Group.findAll().then((groups) => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.set("allGroups", groups);
    });
  }

  @action
  setGroupField(groupIds) {
    this.onChangeField(this.field, "value", groupIds?.firstObject);
  }
}
