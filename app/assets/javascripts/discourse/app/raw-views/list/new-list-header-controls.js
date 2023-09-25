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

  @discourseComputed
  staticLabel() {
    if (this.noStaticLabel) {
      return null;
    }
    if (this.newTopicsCount > 0 && this.newRepliesCount > 0) {
      return null;
    }
    if (this.newTopicsCount > 0) {
      return this.topicsButtonLabel;
    } else {
      return this.repliesButtonLabel;
    }
  },
});
