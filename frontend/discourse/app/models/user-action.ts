import { computed } from "@ember/object";
import { service } from "@ember/service";
import { emojiUnescape } from "discourse/lib/text";
import { userPath } from "discourse/lib/url";
import { escapeExpression, postUrl } from "discourse/lib/utilities";
import RestModel, { type RestModelAttrs } from "discourse/models/rest";
import type { TopicBasicUser } from "discourse/models/topic";
import type User from "discourse/models/user";
import UserActionGroup from "discourse/models/user-action-group";
import Category from "./category.ts";

/** Fields shared by the activity and admin post feeds; feed-specific fields are optional. */
export interface UserActionFields {
  action_type: number | null;
  created_at: string;
  avatar_template: string;
  topic_id: number;
  post_id: number | null;
  post_number: number | null;
  title: string | null;
  username: string | null;
  name?: string | null;
  slug?: string | null;
  category_id: number | null;
  deleted: boolean;
  hidden: boolean | null;
  acting_username?: string | null;
  acting_avatar_template?: string;
  acting_name?: string | null;
  acting_user_id?: number;
  target_username?: string | null;
  target_name?: string | null;
  target_user_id?: number;
  user_id?: number;
  post_type?: number | null;
  reply_to_post_number?: number | null;
  excerpt?: string | null;
  truncated?: true;
  deleted_at?: string | null;
  deleted_by?: TopicBasicUser;
  id?: number;
  moderator_action?: boolean;
  action_code?: string | null;
  action_code_who?: string;
  action_code_path?: string;
  edit_reason?: string | null;
  closed?: boolean;
  archived?: boolean;
  description?: string;
  childGroups?: Record<
    "likes" | "stars" | "edits" | "bookmarks",
    UserActionGroup
  >;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface UserAction extends UserActionFields {}

const UserActionTypes = {
  likes_given: 1,
  likes_received: 2,
  bookmarks: 3,
  topics: 4,
  posts: 5,
  replies: 6,
  mentions: 7,
  quotes: 9,
  edits: 11,
  messages_sent: 12,
  messages_received: 13,
  links: 17,
};
const InvertedActionTypes: Record<string, number | undefined> = {};

Object.keys(UserActionTypes).forEach(
  (k) =>
    (InvertedActionTypes[k] =
      UserActionTypes[k as keyof typeof UserActionTypes])
);

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class UserAction extends RestModel {
  static TYPES = UserActionTypes;

  static TYPES_INVERTED = InvertedActionTypes;

  static TO_COLLAPSE = [
    UserActionTypes.likes_given,
    UserActionTypes.likes_received,
    UserActionTypes.edits,
    UserActionTypes.bookmarks,
  ];

  static TO_SHOW = [
    UserActionTypes.likes_given,
    UserActionTypes.likes_received,
    UserActionTypes.edits,
    UserActionTypes.bookmarks,
    UserActionTypes.messages_sent,
    UserActionTypes.messages_received,
  ];

  static collapseStream(stream: UserAction[]): UserAction[] {
    const uniq: Record<string, number | undefined> = {};
    const collapsed: UserAction[] = [];
    let pos = 0;

    stream.forEach((item) => {
      const key = "" + item.topic_id + "-" + item.post_number;
      const found = uniq[key];
      if (found === void 0) {
        let current;
        if (
          (UserAction.TO_COLLAPSE as (number | null)[]).includes(
            item.action_type
          )
        ) {
          // TODO(typescript-pending): RestModelAttrs requires an index signature; remove when create accepts model instances.
          current = UserAction.create(item as RestModelAttrs<UserAction>);
          item.switchToActing();
          current.addChild(item);
        } else {
          current = item;
        }
        uniq[key] = pos;
        collapsed[pos] = current;
        pos += 1;
      } else {
        if (
          (UserAction.TO_COLLAPSE as (number | null)[]).includes(
            item.action_type
          )
        ) {
          item.switchToActing();
          collapsed[found].addChild(item);
        } else {
          collapsed[found].setProperties(
            item.getProperties("action_type", "description")
          );
        }
      }
    });
    return collapsed;
  }

  @service currentUser!: User | null;

  @computed("name", "username")
  get presentName(): string | null | undefined {
    return this.name || this.username;
  }

  @computed("target_name", "target_username")
  get targetDisplayName() {
    return this.target_name || this.target_username;
  }

  @computed("acting_name", "acting_username")
  get actingDisplayName() {
    return this.acting_name || this.acting_username;
  }

  @computed("action_type")
  get replyType() {
    return this.action_type === UserActionTypes.replies;
  }

  @computed("action_type")
  get postType() {
    return this.action_type === UserActionTypes.posts;
  }

  @computed("action_type")
  get topicType() {
    return this.action_type === UserActionTypes.topics;
  }

  @computed("action_type")
  get bookmarkType() {
    return this.action_type === UserActionTypes.bookmarks;
  }

  @computed("action_type")
  get messageSentType() {
    return this.action_type === UserActionTypes.messages_sent;
  }

  @computed("action_type")
  get messageReceivedType() {
    return this.action_type === UserActionTypes.messages_received;
  }

  @computed("action_type")
  get mentionType() {
    return this.action_type === UserActionTypes.mentions;
  }

  @computed("messageSentType", "messageReceivedType")
  get isPM() {
    return this.messageSentType || this.messageReceivedType;
  }

  @computed("postType", "replyType")
  get postReplyType() {
    return this.postType || this.replyType;
  }

  @computed("category_id")
  get category() {
    return Category.findById(this.category_id);
  }

  @computed("action_type")
  get descriptionKey() {
    if (
      this.action_type === null ||
      UserAction.TO_SHOW.includes(this.action_type)
    ) {
      if (this.isPM) {
        return this.sameUser ? "sent_by_you" : "sent_by_user";
      } else {
        return this.sameUser ? "posted_by_you" : "posted_by_user";
      }
    }

    if (this.topicType) {
      return this.sameUser ? "you_posted_topic" : "user_posted_topic";
    }

    if (this.postReplyType) {
      if (this.reply_to_post_number) {
        return this.sameUser ? "you_replied_to_post" : "user_replied_to_post";
      } else {
        return this.sameUser ? "you_replied_to_topic" : "user_replied_to_topic";
      }
    }

    if (this.mentionType) {
      if (this.sameUser) {
        return "you_mentioned_user";
      } else {
        return this.targetUser ? "user_mentioned_you" : "user_mentioned_user";
      }
    }
  }

  @computed("username")
  get sameUser() {
    return this.username === this.currentUser?.get("username");
  }

  @computed("target_username")
  get targetUser() {
    return this.target_username === this.currentUser?.get("username");
  }

  @computed("target_username")
  get targetUserUrl(): string {
    return userPath(this.target_username);
  }

  /** Requires a username; null usernames throw when this getter is accessed. */
  @computed("username")
  get usernameLower() {
    return this.username!.toLowerCase();
  }

  @computed("usernameLower")
  get userUrl(): string {
    return userPath(this.usernameLower);
  }

  @computed()
  get postUrl(): string {
    return postUrl(this.slug, this.topic_id, this.post_number);
  }

  @computed()
  get replyUrl(): string {
    return postUrl(this.slug, this.topic_id, this.reply_to_post_number);
  }

  @computed("title")
  get titleHtml(): string | null {
    return this.title && emojiUnescape(escapeExpression(this.title));
  }

  @computed(
    "childGroups",
    "childGroups.likes.items",
    "childGroups.likes.items.[]",
    "childGroups.stars.items",
    "childGroups.stars.items.[]",
    "childGroups.edits.items",
    "childGroups.edits.items.[]",
    "childGroups.bookmarks.items",
    "childGroups.bookmarks.items.[]"
  )
  get children() {
    const g = this.childGroups;
    let rval: UserActionGroup[] = [];
    if (g) {
      rval = [g.likes, g.stars, g.edits, g.bookmarks].filter(function (i) {
        return i.get("items") && i.get("items")!.length > 0;
      });
    }
    return rval;
  }

  addChild(action: UserAction): void {
    let groups = this.childGroups;
    if (!groups) {
      groups = {
        likes: UserActionGroup.create({ icon: "heart" }),
        stars: UserActionGroup.create({ icon: "star" }),
        edits: UserActionGroup.create({ icon: "pencil" }),
        bookmarks: UserActionGroup.create({ icon: "bookmark" }),
      };
    }
    this.set("childGroups", groups);

    const bucket = (function () {
      switch (action.action_type) {
        case UserActionTypes.likes_given:
        case UserActionTypes.likes_received:
          return "likes";
        case UserActionTypes.edits:
          return "edits";
        case UserActionTypes.bookmarks:
          return "bookmarks";
      }
    })();
    // Unsupported action types retain the existing undefined-key lookup.
    const current = groups[bucket as keyof typeof groups];
    if (current) {
      current.push(action);
    }
  }

  /** Copies the acting identity, including undefined when the row omits it. */
  switchToActing() {
    this.setProperties({
      // Admin post rows omit the acting user; preserve the existing undefined assignment.
      username: this.acting_username as string | null,
      name: this.actingDisplayName,
    });
  }
}
