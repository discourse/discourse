import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import putCursorAtEnd from "discourse/lib/put-cursor-at-end";

export default Component.extend({
  init() {
    this._super(...arguments);
    this.set("__groups", []);
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

  __updateGroups(selected, newGroups) {
    const groups = [];
    this.__groups.forEach((existing) => {
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
      __groups: groups,
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
      this.__updateGroups(selected, newGroups);
      this.set("recipients", selected.join(","));
    },
  },
});
