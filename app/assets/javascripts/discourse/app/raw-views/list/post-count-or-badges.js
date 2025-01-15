import EmberObject from "@ember/object";
import { and } from "@ember/object/computed";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class PostCountOrBadges extends EmberObject {
  @and("postBadgesEnabled", "topic.unread_posts") showBadges;

  @discourseComputed
  newDotText() {
    return this.currentUser && this.currentUser.trust_level > 0
      ? ""
      : i18n("filters.new.lower_title");
  }
}
