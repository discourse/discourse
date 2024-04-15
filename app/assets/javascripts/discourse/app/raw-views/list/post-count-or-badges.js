import EmberObject from "@ember/object";
import { and } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default EmberObject.extend({
  showBadges: and("postBadgesEnabled", "topic.unread_posts"),

  @discourseComputed
  newDotText() {
    return this.currentUser && this.currentUser.trust_level > 0
      ? ""
      : I18n.t("filters.new.lower_title");
  },
});
