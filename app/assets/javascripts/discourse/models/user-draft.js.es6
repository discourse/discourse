import discourseComputed from "discourse-common/utils/decorators";
import RestModel from "discourse/models/rest";
import { postUrl } from "discourse/lib/utilities";
import { userPath } from "discourse/lib/url";
import User from "discourse/models/user";
import {
  NEW_TOPIC_KEY,
  NEW_PRIVATE_MESSAGE_KEY
} from "discourse/models/composer";

export default RestModel.extend({
  @discourseComputed("draft_username")
  editableDraft(draftUsername) {
    return draftUsername === User.currentProp("username");
  },

  @discourseComputed("username_lower")
  userUrl(usernameLower) {
    return userPath(usernameLower);
  },

  @discourseComputed("topic_id")
  postUrl(topicId) {
    if (!topicId) return;

    return postUrl(this.slug, this.topic_id, this.post_number);
  },

  @discourseComputed("draft_key")
  draftType(draftKey) {
    switch (draftKey) {
      case NEW_TOPIC_KEY:
        return I18n.t("drafts.new_topic");
      case NEW_PRIVATE_MESSAGE_KEY:
        return I18n.t("drafts.new_private_message");
      default:
        return false;
    }
  }
});
