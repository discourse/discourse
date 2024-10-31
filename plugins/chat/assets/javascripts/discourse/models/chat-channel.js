import { tracked } from "@glimmer/tracking";
import guid from "pretty-text/guid";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import ChatMessagesManager from "discourse/plugins/chat/discourse/lib/chat-messages-manager";
import ChatThreadsManager from "discourse/plugins/chat/discourse/lib/chat-threads-manager";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";
import ChatChannelArchive from "discourse/plugins/chat/discourse/models/chat-channel-archive";
import ChatDirectMessage from "discourse/plugins/chat/discourse/models/chat-direct-message";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatTrackingState from "discourse/plugins/chat/discourse/models/chat-tracking-state";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";

export const CHATABLE_TYPES = {
  directMessageChannel: "DirectMessage",
  categoryChannel: "Category",
};

export const CHANNEL_STATUSES = {
  open: "open",
  readOnly: "read_only",
  closed: "closed",
  archived: "archived",
};

export function channelStatusIcon(channelStatus) {
  if (channelStatus === CHANNEL_STATUSES.open) {
    return null;
  }

  switch (channelStatus) {
    case CHANNEL_STATUSES.closed:
      return "lock";
    case CHANNEL_STATUSES.readOnly:
      return "comment-slash";
    case CHANNEL_STATUSES.archived:
      return "archive";
  }
}

const STAFF_READONLY_STATUSES = [
  CHANNEL_STATUSES.readOnly,
  CHANNEL_STATUSES.archived,
];

const READONLY_STATUSES = [
  CHANNEL_STATUSES.closed,
  CHANNEL_STATUSES.readOnly,
  CHANNEL_STATUSES.archived,
];

export default class ChatChannel {
  static create(args = {}) {
    return new ChatChannel(args);
  }

  @tracked title;
  @tracked slug;
  @tracked description;
  @tracked status;
  @tracked activeThread;
  @tracked meta;
  @tracked chatableId;
  @tracked chatableType;
  @tracked chatableUrl;
  @tracked autoJoinUsers;
  @tracked allowChannelWideMentions;
  @tracked membershipsCount;
  @tracked archive;
  @tracked tracking;
  @tracked threadingEnabled;
  @tracked draft;

  threadsManager = new ChatThreadsManager(getOwnerWithFallback(this));
  messagesManager = new ChatMessagesManager(getOwnerWithFallback(this));

  @tracked _currentUserMembership;
  @tracked _lastMessage;

  constructor(args = {}) {
    this.id = args.id;
    this.chatableId = args.chatable_id;
    this.chatableUrl = args.chatable_url;
    this.chatableType = args.chatable_type;
    this.membershipsCount = args.memberships_count;
    this.slug = args.slug;
    this.title = args.title;
    this.status = args.status;
    this.description = args.description;
    this.threadingEnabled = args.threading_enabled;
    this.autoJoinUsers = args.auto_join_users;
    this.allowChannelWideMentions = args.allow_channel_wide_mentions;
    this.currentUserMembership = args.current_user_membership;
    this.lastMessage = args.last_message;
    this.meta = args.meta;

    this.chatable = this.#initChatable(args.chatable ?? []);
    this.tracking = new ChatTrackingState(getOwnerWithFallback(this));

    if (args.archive_completed || args.archive_failed) {
      this.archive = ChatChannelArchive.create(args);
    }
  }

  get unreadThreadsCountSinceLastViewed() {
    return Array.from(this.threadsManager.unreadThreadOverview.values()).filter(
      (lastReplyCreatedAt) =>
        lastReplyCreatedAt >= this.currentUserMembership.lastViewedAt
    ).length;
  }

  get unreadThreadsCount() {
    return this.threadsManager.unreadThreadCount;
  }

  get watchedThreadsUnreadCount() {
    return this.threadsManager.threads.reduce((unreadCount, thread) => {
      return unreadCount + thread.tracking.watchedThreadsUnreadCount;
    }, 0);
  }

  updateLastViewedAt() {
    this.currentUserMembership.lastViewedAt = new Date();
  }

  get canDeleteSelf() {
    return this.meta.can_delete_self;
  }

  get canDeleteOthers() {
    return this.meta.can_delete_others;
  }

  get canFlag() {
    return this.meta.can_flag;
  }

  get userSilenced() {
    return this.meta.user_silenced;
  }

  get canModerate() {
    return this.meta.can_moderate;
  }

  get escapedTitle() {
    return escapeExpression(this.title);
  }

  get escapedDescription() {
    return escapeExpression(this.description);
  }

  get slugifiedTitle() {
    return this.slug || slugifyChannel(this);
  }

  get routeModels() {
    return [this.slugifiedTitle, this.id];
  }

  get isDirectMessageChannel() {
    return this.chatableType === CHATABLE_TYPES.directMessageChannel;
  }

  get isCategoryChannel() {
    return this.chatableType === CHATABLE_TYPES.categoryChannel;
  }

  get isOpen() {
    return !this.status || this.status === CHANNEL_STATUSES.open;
  }

  get isReadOnly() {
    return this.status === CHANNEL_STATUSES.readOnly;
  }

  get isClosed() {
    return this.status === CHANNEL_STATUSES.closed;
  }

  get isArchived() {
    return this.status === CHANNEL_STATUSES.archived;
  }

  get isJoinable() {
    return this.isOpen && !this.isArchived;
  }

  get isFollowing() {
    return this.currentUserMembership.following;
  }

  get canJoin() {
    return this.meta.can_join_chat_channel;
  }

  async stageMessage(message) {
    message.id = guid();
    message.staged = true;
    message.processed = false;
    message.draft = false;
    message.createdAt = new Date();
    message.channel = this;

    if (message.inReplyTo) {
      if (!this.threadingEnabled) {
        this.messagesManager.addMessages([message]);
      }
    } else {
      this.messagesManager.addMessages([message]);
    }

    message.manager = this.messagesManager;
  }

  resetDraft(user) {
    this.draft = ChatMessage.createDraftMessage(this, {
      user,
    });
  }

  canModifyMessages(user) {
    if (user.staff) {
      return !STAFF_READONLY_STATUSES.includes(this.status);
    }

    return !READONLY_STATUSES.includes(this.status);
  }

  get currentUserMembership() {
    return this._currentUserMembership;
  }

  set currentUserMembership(membership) {
    if (membership instanceof UserChatChannelMembership) {
      this._currentUserMembership = membership;
    } else {
      this._currentUserMembership =
        UserChatChannelMembership.create(membership);
    }
  }

  get lastMessage() {
    return this._lastMessage;
  }

  set lastMessage(message) {
    if (!message) {
      this._lastMessage = null;
      return;
    }

    if (message instanceof ChatMessage) {
      this._lastMessage = message;
    } else {
      this._lastMessage = ChatMessage.create(this, message);
    }
  }

  #initChatable(chatable) {
    if (
      !chatable ||
      chatable instanceof Category ||
      chatable instanceof ChatDirectMessage
    ) {
      return chatable;
    } else {
      if (this.isDirectMessageChannel) {
        return ChatDirectMessage.create({
          users: chatable?.users,
          group: chatable?.group,
        });
      } else {
        return Category.create(chatable);
      }
    }
  }
}
