import Component from "@ember/component";
import { action } from "@ember/object";
import { logSearchLinkClick } from "discourse/lib/search";
import { modKeysPressed } from "discourse/lib/utilities";

export default Component.extend({
  tagName: "div",
  classNames: ["fps-result"],
  classNameBindings: ["bulkSelectEnabled"],
  attributeBindings: ["role"],
  role: "listitem",

  @action
  logClick(topicId, event) {
    // Avoid click logging when any modifier keys are pressed.
    if (event && modKeysPressed(event).length > 0) {
      return false;
    }
    if (this.searchLogId && topicId) {
      logSearchLinkClick({
        searchLogId: this.searchLogId,
        searchResultId: topicId,
        searchResultType: "topic",
      });
    }
  },
});
