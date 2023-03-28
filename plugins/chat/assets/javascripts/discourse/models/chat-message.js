import User from "discourse/models/user";
import { cached, tracked } from "@glimmer/tracking";
import { TrackedArray, TrackedObject } from "@ember-compat/tracked-built-ins";
import ChatMessageReaction from "discourse/plugins/chat/discourse/models/chat-message-reaction";
import Bookmark from "discourse/models/bookmark";
import I18n from "I18n";
import guid from "pretty-text/guid";

export default class ChatMessage {
  static cookFunction = null;

  static create(channel, args = {}) {
    return new ChatMessage(channel, args);
  }

  static createStagedMessage(channel, args = {}) {
    args.id = guid();
    args.staged = true;
    return new ChatMessage(channel, args);
  }

  @tracked id;
  @tracked error;
  @tracked selected;
  @tracked channel;
  @tracked staged = false;
  @tracked channelId;
  @tracked createdAt;
  @tracked deletedAt;
  @tracked uploads;
  @tracked excerpt;
  @tracked message;
  @tracked threadId;
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
    this.message = args.message;
    this.cooked = args.cooked || ChatMessage.cookFunction(this.message);
    this.reactions = this.#initChatMessageReactionModel(
      args.id,
      args.reactions
    );
    this.uploads = new TrackedArray(args.uploads || []);
    this.user = this.#initUserModel(args.user);
    this.bookmark = args.bookmark ? Bookmark.create(args.bookmark) : null;
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
        existingReaction.count = existingReaction.count - 1;

        if (selfReaction) {
          existingReaction.reacted = false;
        }

        if (existingReaction.count === 0) {
          this.reactions.removeObject(existingReaction);
        } else {
          existingReaction.users.removeObject(
            existingReaction.users.find((user) => user.id === actor.id)
          );
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
