import Component from "@ember/component";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",
  hidden: false,

  didInsertElement() {
    this._super(...arguments);

    if (this.noticeKey && this.keyValueStore.getItem(this.noticeKey)) {
      this.set("hidden", true);
    }
  },

  @discourseComputed("noticeId")
  noticeKey(noticeId) {
    if (noticeId) {
      return `dismiss_topic_nav_popup_${noticeId}`;
    }
  },

  @action
  close() {
    this.set("hidden", true);

    if (this.noticeId) {
      this.keyValueStore.setItem(this.noticeKey, true);
    }
  },
});
