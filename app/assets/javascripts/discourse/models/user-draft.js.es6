import RestModel from "discourse/models/rest";
import computed from "ember-addons/ember-computed-decorators";
import { postUrl } from "discourse/lib/utilities";
import { userPath } from "discourse/lib/url";
import User from "discourse/models/user";

import {
  NEW_TOPIC_KEY,
  NEW_PRIVATE_MESSAGE_KEY
} from "discourse/models/composer";

export default RestModel.extend({
  @computed("draft_username")
  editableDraft(draftUsername) {
    return draftUsername === User.currentProp("username");
  },

  @computed("username")
  usernameLower(username) {
    return username.toLowerCase();
  },

  @computed("usernameLower")
  userUrl(usernameLower) {
    return userPath(usernameLower);
  },

  @computed("topic_id")
  postUrl(topicId) {
    if (!topicId) return;

    return postUrl(
      this.get("slug"),
      this.get("topic_id"),
      this.get("post_number")
    );
  },

  @computed("draft_key", "post_number")
  draftType(draftKey, postNumber) {
    switch (draftKey) {
      case NEW_TOPIC_KEY:
        return I18n.t("drafts.new_topic");
      case NEW_PRIVATE_MESSAGE_KEY:
        return I18n.t("drafts.new_private_message");
      default:
        return postNumber
          ? I18n.t("drafts.post_reply", { postNumber })
          : I18n.t("drafts.topic_reply");
    }
  }
});
