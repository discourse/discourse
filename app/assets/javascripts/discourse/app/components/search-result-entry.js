import Component from "@ember/component";
import { action } from "@ember/object";
import { logSearchLinkClick } from "discourse/lib/search";

export default Component.extend({
  tagName: "div",
  classNames: ["fps-result"],
  classNameBindings: ["bulkSelectEnabled"],
  attributeBindings: ["role"],
  role: "listitem",

  @action
  logClick(topicId) {
    if (this.searchLogId && topicId) {
      logSearchLinkClick({
        searchLogId: this.searchLogId,
        searchResultId: topicId,
        searchResultType: "topic",
      });
    }
  },
});
