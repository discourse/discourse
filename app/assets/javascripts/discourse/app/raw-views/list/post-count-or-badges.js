import { or, and } from "@ember/object/computed";
import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default EmberObject.extend({
  postCountsPresent: or("topic.unread", "topic.displayNewPosts"),
  showBadges: and("postBadgesEnabled", "postCountsPresent"),

  @discourseComputed
  newDotText() {
    return this.currentUser && this.currentUser.trust_level > 0
      ? ""
      : I18n.t("filters.new.lower_title");
  }
});
