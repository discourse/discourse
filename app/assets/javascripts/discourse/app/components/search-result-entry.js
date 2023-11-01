import Component from "@ember/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { topicTitleDecorators } from "discourse/components/topic-title";
import { logSearchLinkClick } from "discourse/lib/search";
import { modKeysPressed } from "discourse/lib/utilities";

export default Component.extend({
  tagName: "div",
  classNames: ["fps-result"],
  classNameBindings: ["bulkSelectEnabled"],
  attributeBindings: ["role"],
  role: "listitem",

  didInsertElement() {
    this._super(...arguments);

    schedule("afterRender", () => {
      if (this.element && !this.isDestroying && !this.isDestroyed) {
        const topicTitle = this.element.querySelector(".topic-title");
        if (topicTitle && this.post.topic) {
          topicTitleDecorators.forEach((cb) =>
            cb(this.post.topic, topicTitle, "full-page-search-topic-title")
          );
        }
      }
    });
  },

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
