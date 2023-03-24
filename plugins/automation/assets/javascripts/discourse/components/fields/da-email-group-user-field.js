import BaseField from "./da-base-field";
import { action, computed } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default class EmailGroupUserField extends BaseField {
  init() {
    super.init(...arguments);
    this.set("_groups", []);
  }

  didInsertElement() {
    this._super(...arguments);

    if (this.focusTarget === "usernames") {
      this.element.querySelector(".select-kit .select-kit-header").focus();
    }
  }

  @discourseComputed("recipients")
  splitRecipients(recipients) {
    if (Array.isArray(recipients)) {
      return recipients;
    }
    return recipients ? recipients.split(",").filter(Boolean) : [];
  }

  _updateGroups(selected, newGroups) {
    const groups = [];
    this._groups.forEach((existing) => {
      if (selected.includes(existing)) {
        groups.addObject(existing);
      }
    });
    newGroups.forEach((newGroup) => {
      if (!groups.includes(newGroup)) {
        groups.addObject(newGroup);
      }
    });
    this.setProperties({
      _groups: groups,
      hasGroups: groups.length > 0,
    });
  }

  @action
  updateRecipients(selected, content) {
    const newGroups = content.filterBy("isGroup").mapBy("id");
    this._updateGroups(selected, newGroups);
    this.set("recipients", selected.join(","));
  }

  @computed("field.extra.content.[]")
  get replacedContent() {
    return (this.field.extra.content || []).map((r) => {
      return {
        id: r.id,
        name: r.name,
      };
    });
  }
}
