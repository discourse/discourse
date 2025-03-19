import Component from "@ember/component";
import { action } from "@ember/object";
import discourseComputed from "discourse/lib/decorators";

export default class ComposerUserSelector extends Component {
  _groups = [];

  didInsertElement() {
    super.didInsertElement(...arguments);

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
}
