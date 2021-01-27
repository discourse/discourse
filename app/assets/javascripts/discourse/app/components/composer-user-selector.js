import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import putCursorAtEnd from "discourse/lib/put-cursor-at-end";

export default Component.extend({
  init() {
    this._super(...arguments);
    this.set("_groups", []);
  },

  didInsertElement() {
    this._super(...arguments);

    if (this.focusTarget === "usernames") {
      putCursorAtEnd(this.element.querySelector("input"));
    }
  },

  @discourseComputed("recipients")
  splitRecipients(recipients) {
    return recipients ? recipients.split(",").filter(Boolean) : [];
  },

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
  },

  actions: {
    updateRecipients(selected, content) {
      const newGroups = [];
      selected.forEach((recipient) => {
        const recipientObj = content.findBy("id", recipient);
        if (recipientObj.isGroup) {
          newGroups.addObject(recipient);
        }
      });
      this._updateGroups(selected, newGroups);
      this.set("recipients", selected.join(","));
    },
  },
});
