import {
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import I18n from "I18n";
import RestModel from "discourse/models/rest";
import User from "discourse/models/user";
import discourseComputed from "discourse-common/utils/decorators";
import { postUrl } from "discourse/lib/utilities";
import { userPath } from "discourse/lib/url";

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
    if (!topicId) {
      return;
    }

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
  },
});
