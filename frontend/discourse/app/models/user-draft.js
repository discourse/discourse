import { computed } from "@ember/object";
import { service } from "@ember/service";
import replaceEmoji from "discourse/helpers/replace-emoji";
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

  @computed("draft_username")
  get editableDraft() {
    return this.draft_username === this.currentUser?.get("username");
  }

  @computed("username_lower")
  get userUrl() {
    return userPath(this.username_lower);
  }

  @computed("topic_id")
  get postUrl() {
    if (!this.topic_id) {
      return;
    }

    return postUrl(this.slug, this.topic_id, this.post_number);
  }

  @computed("draft_key")
  get draftType() {
    if (this.draft_key.startsWith(NEW_TOPIC_KEY)) {
      return i18n("drafts.new_topic");
    } else if (this.draft_key.startsWith(NEW_PRIVATE_MESSAGE_KEY)) {
      return i18n("drafts.new_private_message");
    } else if (this.draft_key.startsWith(EDIT_TOPIC_KEY)) {
      return i18n("drafts.edit_topic");
    }
    return false;
  }
}
