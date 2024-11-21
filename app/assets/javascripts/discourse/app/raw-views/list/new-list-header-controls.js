import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class NewListHeaderControls extends EmberObject {
  @discourseComputed
  topicsActive() {
    return this.current === "topics";
  }

  @discourseComputed
  repliesActive() {
    return this.current === "replies";
  }

  @discourseComputed
  allActive() {
    return !this.topicsActive && !this.repliesActive;
  }

  @discourseComputed
  repliesButtonLabel() {
    if (this.newRepliesCount > 0) {
      return i18n("filters.new.replies_with_count", {
        count: this.newRepliesCount,
      });
    } else {
      return i18n("filters.new.replies");
    }
  }

  @discourseComputed
  topicsButtonLabel() {
    if (this.newTopicsCount > 0) {
      return i18n("filters.new.topics_with_count", {
        count: this.newTopicsCount,
      });
    } else {
      return i18n("filters.new.topics");
    }
  }

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
  }
}
