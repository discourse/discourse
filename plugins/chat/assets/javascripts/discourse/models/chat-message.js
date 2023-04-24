import User from "discourse/models/user";
import { cached, tracked } from "@glimmer/tracking";
import { TrackedArray, TrackedObject } from "@ember-compat/tracked-built-ins";
import ChatMessageReaction from "discourse/plugins/chat/discourse/models/chat-message-reaction";
import Bookmark from "discourse/models/bookmark";
import I18n from "I18n";
import { generateCookFunction } from "discourse/lib/text";
import simpleCategoryHashMentionTransform from "discourse/plugins/chat/discourse/lib/simple-category-hash-mention-transform";
import { getOwner } from "discourse-common/lib/get-owner";

export default class ChatMessage {
  static cookFunction = null;

  static create(channel, args = {}) {
    return new ChatMessage(channel, args);
  }

  static createDraftMessage(channel, args = {}) {
    args.draft = true;
    return new ChatMessage(channel, args);
  }

  @tracked id;
  @tracked error;
  @tracked selected;
  @tracked channel;
  @tracked staged = false;
  @tracked draft = false;
  @tracked channelId;
  @tracked createdAt;
  @tracked deletedAt;
  @tracked uploads;
  @tracked excerpt;
  @tracked message;
  @tracked threadId;
  @tracked threadReplyCount;
  @tracked reactions;
  @tracked reviewableId;
  @tracked user;
  @tracked cooked;
  @tracked inReplyTo;
  @tracked expanded;
  @tracked bookmark;
  @tracked userFlagStatus;
  @tracked hidden;
  @tracked version = 0;
  @tracked edited;
  @tracked chatWebhookEvent = new TrackedObject();
  @tracked mentionWarning;
  @tracked availableFlags;
  @tracked newest = false;
  @tracked highlighted = false;
  @tracked firstOfResults = false;

  constructor(channel, args = {}) {
    this.channel = channel;
    this.id = args.id;
    this.newest = args.newest;
    this.firstOfResults = args.firstOfResults;
    this.staged = args.staged;
    this.edited = args.edited;
    this.availableFlags = args.availableFlags || args.available_flags;
    this.hidden = args.hidden;
    this.threadId = args.threadId || args.thread_id;
    this.threadReplyCount = args.threadReplyCount || args.thread_reply_count;
    this.channelId = args.channelId || args.chat_channel_id;
    this.chatWebhookEvent = args.chatWebhookEvent || args.chat_webhook_event;
    this.createdAt = args.createdAt || args.created_at;
    this.deletedAt = args.deletedAt || args.deleted_at;
    this.excerpt = args.excerpt;
    this.reviewableId = args.reviewableId || args.reviewable_id;
    this.userFlagStatus = args.userFlagStatus || args.user_flag_status;
    this.inReplyTo =
      args.inReplyTo || args.in_reply_to
        ? ChatMessage.create(channel, args.in_reply_to)
        : null;
    this.draft = args.draft;
    this.message = args.message || "";

    if (args.cooked) {
      this.cooked = args.cooked;
    } else {
      this.cooked = "";
      this.cook();
    }

    this.reactions = this.#initChatMessageReactionModel(
      args.id,
      args.reactions
    );
    this.uploads = new TrackedArray(args.uploads || []);
    this.user = this.#initUserModel(args.user);
    this.bookmark = args.bookmark ? Bookmark.create(args.bookmark) : null;
  }

  cook() {
    const site = getOwner(this).lookup("service:site");

    const markdownOptions = {
      featuresOverride:
        site.markdown_additional_options?.chat?.limited_pretty_text_features,
      markdownItRules:
        site.markdown_additional_options?.chat
          ?.limited_pretty_text_markdown_rules,
      hashtagTypesInPriorityOrder:
        site.hashtag_configurations?.["chat-composer"],
      hashtagIcons: site.hashtag_icons,
    };

    if (ChatMessage.cookFunction) {
      this.cooked = ChatMessage.cookFunction(this.message);
      this.incrementVersion();
    } else {
      generateCookFunction(markdownOptions).then((cookFunction) => {
        ChatMessage.cookFunction = (raw) => {
          return simpleCategoryHashMentionTransform(
            cookFunction(raw),
            site.categories
          );
        };

        this.cooked = ChatMessage.cookFunction(this.message);
        this.incrementVersion();
      });
    }
  }

  get threadRouteModels() {
    return [...this.channel.routeModels, this.threadId];
  }

  get read() {
    return this.channel.currentUserMembership?.last_read_message_id >= this.id;
  }

  get firstMessageOfTheDayAt() {
    if (!this.previousMessage) {
      return this.#calendarDate(this.createdAt);
    }

    if (
      !this.#areDatesOnSameDay(
        new Date(this.previousMessage.createdAt),
        new Date(this.createdAt)
      )
    ) {
      return this.#calendarDate(this.createdAt);
    }
  }

  #calendarDate(date) {
    return moment(date).calendar(moment(), {
      sameDay: `[${I18n.t("chat.chat_message_separator.today")}]`,
      lastDay: `[${I18n.t("chat.chat_message_separator.yesterday")}]`,
      lastWeek: "LL",
      sameElse: "LL",
    });
  }

  @cached
  get index() {
    return this.channel.messages.indexOf(this);
  }

  @cached
  get previousMessage() {
    return this.channel?.messages?.objectAt?.(this.index - 1);
  }

  @cached
  get nextMessage() {
    return this.channel?.messages?.objectAt?.(this.index + 1);
  }

  incrementVersion() {
    this.version++;
  }

  toJSONDraft() {
    if (
      this.message?.length === 0 &&
      this.uploads?.length === 0 &&
      !this.replyToMsg
    ) {
      return null;
    }

    const data = {};

    if (this.uploads?.length > 0) {
      data.uploads = this.uploads;
    }

    if (this.message?.length > 0) {
      data.message = this.message;
    }

    if (this.replyToMsg) {
      data.replyToMsg = this.replyToMsg;
    }

    return JSON.stringify(data);
  }

  react(emoji, action, actor, currentUserId) {
    const selfReaction = actor.id === currentUserId;
    const existingReaction = this.reactions.find(
      (reaction) => reaction.emoji === emoji
    );

    if (existingReaction) {
      if (action === "add") {
        if (selfReaction && existingReaction.reacted) {
          return;
        }

        // we might receive a message bus event while loading a channel who would
        // already have the reaction added to the message
        if (existingReaction.users.find((user) => user.id === actor.id)) {
          return;
        }

        existingReaction.count = existingReaction.count + 1;
        if (selfReaction) {
          existingReaction.reacted = true;
        }
        existingReaction.users.pushObject(actor);
      } else {
        const existingUserReaction = existingReaction.users.find(
          (user) => user.id === actor.id
        );

        if (!existingUserReaction) {
          return;
        }

        if (selfReaction) {
          existingReaction.reacted = false;
        }

        if (existingReaction.count === 1) {
          this.reactions.removeObject(existingReaction);
        } else {
          existingReaction.count = existingReaction.count - 1;
          existingReaction.users.removeObject(existingUserReaction);
        }
      }
    } else {
      if (action === "add") {
        this.reactions.pushObject(
          ChatMessageReaction.create({
            count: 1,
            emoji,
            reacted: selfReaction,
            users: [actor],
          })
        );
      }
    }
  }

  #initChatMessageReactionModel(messageId, reactions = []) {
    return reactions.map((reaction) =>
      ChatMessageReaction.create(Object.assign({ messageId }, reaction))
    );
  }

  #initUserModel(user) {
    if (!user || user instanceof User) {
      return user;
    }

    return User.create(user);
  }

  #areDatesOnSameDay(a, b) {
    return (
      a.getFullYear() === b.getFullYear() &&
      a.getMonth() === b.getMonth() &&
      a.getDate() === b.getDate()
    );
  }
}
