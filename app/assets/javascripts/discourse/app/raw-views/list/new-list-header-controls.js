import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";

export default EmberObject.extend({
  @discourseComputed
  topicsActive() {
    return this.current === "topics";
  },

  @discourseComputed
  repliesActive() {
    return this.current === "replies";
  },

  @discourseComputed
  allActive() {
    return !this.topicsActive && !this.repliesActive;
  },

  @discourseComputed
  allButtonLabel() {
    const count = this.newRepliesCount + this.newTopicsCount;
    if (count > 0) {
      return I18n.t("filters.new.all_with_count", { count });
    } else {
      return I18n.t("filters.new.all");
    }
  },

  @discourseComputed
  repliesButtonLabel() {
    if (this.newRepliesCount > 0) {
      return I18n.t("filters.new.replies_with_count", {
        count: this.newRepliesCount,
      });
    } else {
      return I18n.t("filters.new.replies");
    }
  },

  @discourseComputed
  topicsButtonLabel() {
    if (this.newTopicsCount > 0) {
      return I18n.t("filters.new.topics_with_count", {
        count: this.newTopicsCount,
      });
    } else {
      return I18n.t("filters.new.topics");
    }
  },
});
