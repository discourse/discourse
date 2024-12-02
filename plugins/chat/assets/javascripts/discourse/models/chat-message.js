import { cached, tracked } from "@glimmer/tracking";
import { TrackedArray } from "tracked-built-ins";
import { generateCookFunction, parseMentions } from "discourse/lib/text";
import Bookmark from "discourse/models/bookmark";
import User from "discourse/models/user";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import discourseLater from "discourse-common/lib/later";
import transformAutolinks from "discourse/plugins/chat/discourse/lib/transform-auto-links";
import ChatMessageReaction from "discourse/plugins/chat/discourse/models/chat-message-reaction";

export default class ChatMessage {
  static cookFunction = null;

  static create(channel, args = {}) {
    return new ChatMessage(channel, args);
  }

  static createDraftMessage(channel, args = {}) {
    args.draft = true;
    return ChatMessage.create(channel, args);
  }

  @tracked id;
  @tracked error;
  @tracked selected;
  @tracked channel;
  @tracked staged;
  @tracked processed;
  @tracked draftSaved;
  @tracked draft;
  @tracked createdAt;
  @tracked uploads;
  @tracked excerpt;
  @tracked reactions;
  @tracked reviewableId;
  @tracked user;
  @tracked inReplyTo;
  @tracked expanded;
  @tracked bookmark;
  @tracked userFlagStatus;
  @tracked hidden;
  @tracked version = 0;
  @tracked edited;
  @tracked editing;
  @tracked chatWebhookEvent;
  @tracked mentionWarning;
  @tracked availableFlags;
  @tracked newest;
  @tracked highlighted;
  @tracked firstOfResults;
  @tracked message;
  @tracked manager;
  @tracked deletedById;
  @tracked streaming;

  @tracked _deletedAt;
  @tracked _cooked;
  @tracked _thread;

  constructor(channel, args = {}) {
    this.id = args.id;
    this.channel = channel;
    this.streaming = args.streaming;
    this.manager = args.manager;
    this.newest = args.newest ?? false;
    this.draftSaved = args.draftSaved ?? args.draft_saved ?? false;
    this.firstOfResults = args.firstOfResults ?? args.first_of_results ?? false;
    this.staged = args.staged ?? false;
    this.processed = args.processed ?? true;
    this.edited = args.edited ?? false;
    this.editing = args.editing ?? false;
    this.availableFlags = args.availableFlags ?? args.available_flags;
    this.hidden = args.hidden ?? false;
    this.chatWebhookEvent = args.chatWebhookEvent ?? args.chat_webhook_event;
    this.createdAt = args.created_at
      ? new Date(args.created_at)
      : new Date(args.createdAt);
    this.deletedById = args.deletedById || args.deleted_by_id;
    this._deletedAt = args.deletedAt || args.deleted_at;
    this.expanded =
      this.hidden || this._deletedAt ? false : args.expanded ?? true;
    this.excerpt = args.excerpt;
    this.reviewableId = args.reviewableId ?? args.reviewable_id;
    this.userFlagStatus = args.userFlagStatus ?? args.user_flag_status;
    this.draft = args.draft;
    this.message = args.message ?? "";
    this._cooked = args.cooked ?? "";
    this.inReplyTo =
      args.inReplyTo ??
      (args.in_reply_to ?? args.replyToMsg
        ? ChatMessage.create(channel, args.in_reply_to ?? args.replyToMsg)
        : null);
    this.reactions = this.#initChatMessageReactionModel(args.reactions);
    this.uploads = new TrackedArray(args.uploads || []);
    this.user = this.#initUserModel(args.user);
    this.bookmark = args.bookmark ? Bookmark.create(args.bookmark) : null;
    this.mentionedUsers = this.#initMentionedUsers(args.mentioned_users);
    this.blocks = args.blocks;

    if (args.thread) {
      this.thread = args.thread;
    }
  }

  get persisted() {
    return !!this.id && !this.staged;
  }

  get replyable() {
    return !this.staged && !this.error;
  }

  get editable() {
    return !this.staged && !this.error;
  }

  get thread() {
    return this._thread;
  }

  set thread(thread) {
    if (!thread) {
      this._thread = null;
      return;
    }

    this._thread = this.channel.threadsManager.add(this.channel, thread, {
      replace: true,
    });
  }

  get deletedAt() {
    return this._deletedAt;
  }

  set deletedAt(value) {
    this._deletedAt = value;
    this.incrementVersion();
  }

  get cooked() {
    return this._cooked;
  }

  set cooked(newCooked) {
    // some markdown is cooked differently on the server-side, e.g.
    // quotes, avatar images etc.
    if (newCooked !== this._cooked) {
      this._cooked = newCooked;
      this.incrementVersion();
    }
  }

  async cook() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }
    await this.#ensureCookFunctionInitialized();
    this.cooked = ChatMessage.cookFunction(this.message);
  }

  get read() {
    return this.channel.currentUserMembership?.lastReadMessageId >= this.id;
  }

  get isOriginalThreadMessage() {
    return this.thread?.originalMessage?.id === this.id;
  }

  @cached
  get index() {
    return this.manager?.messages?.indexOf(this);
  }

  @cached
  get previousMessage() {
    return this.manager?.messages?.objectAt?.(this.index - 1);
  }

  @cached
  get nextMessage() {
    return this.manager?.messages?.objectAt?.(this.index + 1);
  }

  highlight() {
    this.highlighted = true;

    discourseLater(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.highlighted = false;
    }, 2000);
  }

  incrementVersion() {
    this.version++;
  }

  async parseMentions() {
    return await parseMentions(this.message, this.#markdownOptions);
  }

  toJSONDraft() {
    if (
      this.message?.length === 0 &&
      this.uploads?.length === 0 &&
      !this.inReplyTo
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

    if (this.inReplyTo) {
      data.replyToMsg = {
        id: this.inReplyTo.id,
        excerpt: this.inReplyTo.excerpt,
        user: {
          id: this.inReplyTo.user.id,
          name: this.inReplyTo.user.name,
          avatar_template: this.inReplyTo.user.avatar_template,
          username: this.inReplyTo.user.username,
        },
      };
    }

    if (this.editing) {
      data.editing = true;
      data.id = this.id;
      data.excerpt = this.excerpt;
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

  async #ensureCookFunctionInitialized() {
    if (ChatMessage.cookFunction) {
      return;
    }

    const cookFunction = await generateCookFunction(this.#markdownOptions);
    ChatMessage.cookFunction = (raw) => {
      return transformAutolinks(cookFunction(raw));
    };
  }

  get #markdownOptions() {
    const site = getOwnerWithFallback(this).lookup("service:site");
    return {
      featuresOverride:
        site.markdown_additional_options?.chat?.limited_pretty_text_features,
      markdownItRules:
        site.markdown_additional_options?.chat
          ?.limited_pretty_text_markdown_rules,
      hashtagTypesInPriorityOrder:
        site.hashtag_configurations?.["chat-composer"],
      hashtagIcons: site.hashtag_icons,
    };
  }

  #initChatMessageReactionModel(reactions = []) {
    return reactions.map((reaction) => ChatMessageReaction.create(reaction));
  }

  #initMentionedUsers(mentionedUsers) {
    const map = new Map();
    if (mentionedUsers) {
      mentionedUsers.forEach((userData) => {
        const user = User.create(userData);
        map.set(user.id, user);
      });
    }
    return map;
  }

  #initUserModel(user) {
    if (!user || user instanceof User) {
      return user;
    }

    return User.create(user);
  }
}
