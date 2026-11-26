import { computed } from "@ember/object";
import { service } from "@ember/service";
import { userPath } from "discourse/lib/url";
import { postUrl } from "discourse/lib/utilities";
import type Category from "discourse/models/category";
import {
  EDIT_TOPIC_KEY,
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import RestModel from "discourse/models/rest";
import type User from "discourse/models/user";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

/** The saved composer state of a draft (`DraftsController#index` sends it as a JSON string). */
export interface UserDraftData {
  /** Null or absent when the composer was cleared or the draft was saved without one. */
  reply?: string | null;
  action?: string;
  title?: string | null;
  categoryId?: number | null;
  postId?: number;
  [key: string]: unknown;
}

/**
 * Data a `UserDraft` holds: the `DraftSerializer` payload plus the fields the
 * drafts stream derives from it before calling `create`.
 */
export interface UserDraftFields {
  created_at: string;
  draft_key: string;
  sequence: number;
  /** The drafter. */
  draft_username: string;
  avatar_template: string;
  /** Parsed from the server's JSON string before the draft is created. */
  data: UserDraftData;
  /** Set for drafts on an existing topic. */
  topic_id: number | null;
  /** The author of the replied-to post or topic, else the drafter. */
  username: string;
  username_lower: string;
  /** Present when names are enabled. */
  name?: string | null;
  user_id: number;
  /**
   * The topic's title. New topic and message drafts use the draft's own
   * title instead, which may be missing.
   */
  title?: string | null;
  /** Present when the topic has a title. */
  slug?: string;
  /** Present when the topic has a category. */
  category_id?: number;
  /** Present only when the topic is closed. */
  closed?: true;
  archetype: string | null;
  /** Present only when the topic is archived. */
  archived?: true;
  /** Derived from the draft's reply before the draft is created. */
  excerpt: string;
  /** Present only when the server's excerpt was cut. */
  truncated?: true;
  post_number: number | null;
  /** Set when the draft's composer state names a category. */
  category?: Category | null;
}

// `create()` assigns the server fields at runtime, so the class declares none of
// them. Merging an interface of the same name adds them to the class type, and
// lets plugins add theirs by augmenting `UserDraftFields`.
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface UserDraft extends UserDraftFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class UserDraft extends RestModel {
  @service declare currentUser: User | null;

  get titleHtml() {
    return dReplaceEmoji(this.get("title"));
  }

  @computed("draft_username")
  get editableDraft() {
    return this.draft_username === this.currentUser?.get("username");
  }

  @computed("username_lower")
  get userUrl(): string {
    return userPath(this.username_lower);
  }

  @computed("topic_id")
  get postUrl(): string | undefined {
    if (!this.topic_id) {
      return;
    }

    return postUrl(this.slug, this.topic_id, this.post_number);
  }

  @computed("draft_key")
  get draftType(): string | false {
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
