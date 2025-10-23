import { service } from "@ember/service";
import replaceEmoji from "discourse/helpers/replace-emoji";
import discourseComputed from "discourse/lib/decorators";
import { userPath } from "discourse/lib/url";
import { postUrl } from "discourse/lib/utilities";
import {
  EDIT_TOPIC_KEY,
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export default class UserDraft extends RestModel {
  @service currentUser;

  get titleHtml() {
    return replaceEmoji(this.get("title"));
  }

  @discourseComputed("draft_username")
  editableDraft(draftUsername) {
    return draftUsername === this.currentUser?.get("username");
  }

  @discourseComputed("username_lower")
  userUrl(usernameLower) {
    return userPath(usernameLower);
  }

  @discourseComputed("topic_id")
  postUrl(topicId) {
    if (!topicId) {
      return;
    }

    return postUrl(this.slug, this.topic_id, this.post_number);
  }

  @discourseComputed("draft_key")
  draftType(draftKey) {
    if (draftKey.startsWith(NEW_TOPIC_KEY)) {
      return i18n("drafts.new_topic");
    } else if (draftKey.startsWith(NEW_PRIVATE_MESSAGE_KEY)) {
      return i18n("drafts.new_private_message");
    } else if (draftKey.startsWith(EDIT_TOPIC_KEY)) {
      return i18n("drafts.edit_topic");
    }
    return false;
  }
}
