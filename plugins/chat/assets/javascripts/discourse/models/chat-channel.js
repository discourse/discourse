import Category from "discourse/models/category";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";
import ChatDirectMessage from "discourse/plugins/chat/discourse/models/chat-direct-message";
import { ajax } from "discourse/lib/ajax";
import { escapeExpression } from "discourse/lib/utilities";
import { tracked } from "@glimmer/tracking";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";
import ChatThreadsManager from "discourse/plugins/chat/discourse/lib/chat-threads-manager";
import ChatMessagesManager from "discourse/plugins/chat/discourse/lib/chat-messages-manager";
import { getOwner } from "discourse-common/lib/get-owner";

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
  static create(args) {
    return new ChatChannel(args);
  }

  @tracked currentUserMembership = null;
  @tracked isDraft = false;
  @tracked title;
  @tracked description;
  @tracked chatableType;
  @tracked status;
  @tracked activeThread;
  @tracked lastMessageSentAt;
  @tracked canDeleteOthers;
  @tracked canDeleteSelf;
  @tracked canFlag;
  @tracked canModerate;
  @tracked userSilenced;
  @tracked draft;
  @tracked meta;
  @tracked threadingEnabled;

  threadsManager = new ChatThreadsManager(getOwner(this));
  messagesManager = new ChatMessagesManager(getOwner(this));

  get messages() {
    return this.messagesManager.messages;
  }

  set messages(messages) {
    this.messagesManager.messages = messages;
  }

  constructor(args = {}) {
    this.id = args.id;
    this.createdAt = args.created_at;
    this.lastMessageSentAt = args.last_message_sent_at;
    this.currentUserMembership = this.#initUserMembership(
      args.current_user_membership
    );
    this.meta = args.meta;
    this.title = args.title;
    this.description = args.description;
    this.chatableType = args.chatable_type;
    this.status = args.status;
    this.chatable = this.#initChatable(args);
    this.membershipsCount = args.memberships_count;
    this.threadingEnabled = args.threading_enabled;
  }

  #initChatable(args) {
    if (args.chatable_type === CHATABLE_TYPES.directMessageChannel) {
      return ChatDirectMessage.create(args.chatable);
    }

    return Category.findById(args.chatable_id);
  }

  #initUserMembership(membership) {
    if (membership instanceof UserChatChannelMembership) {
      return;
    }

    return UserChatChannelMembership.create(
      membership || {
        following: false,
        muted: false,
        unread_count: 0,
        unread_mentions: 0,
      }
    );
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

  get visibleMessages() {
    return this.messages.filter((message) => message.visible);
  }

  set details(details) {
    this.canDeleteOthers = details.can_delete_others ?? false;
    this.canDeleteSelf = details.can_delete_self ?? false;
    this.canFlag = details.can_flag ?? false;
    this.canModerate = details.can_moderate ?? false;
    if (details.can_load_more_future !== undefined) {
      this.messagesManager.canLoadMoreFuture = details.can_load_more_future;
    }
    if (details.can_load_more_past !== undefined) {
      this.messagesManager.canLoadMorePast = details.can_load_more_past;
    }
    this.userSilenced = details.user_silenced ?? false;
    this.status = details.channel_status;
    this.channelMessageBusLastId = details.channel_message_bus_last_id;
  }

  canModifyMessages(user) {
    if (user.staff) {
      return !STAFF_READONLY_STATUSES.includes(this.status);
    }

    return !READONLY_STATUSES.includes(this.status);
  }

  updateMembership(membership) {
    this.currentUserMembership.following = membership.following;
    this.currentUserMembership.muted = membership.muted;
    this.currentUserMembership.desktop_notification_level =
      membership.desktop_notification_level;
    this.currentUserMembership.mobile_notification_level =
      membership.mobile_notification_level;
  }

  updateLastReadMessage(messageId) {
    if (!this.isFollowing || !messageId) {
      return;
    }

    if (this.currentUserMembership.last_read_message_id >= messageId) {
      return;
    }

    return ajax(`/chat/${this.id}/read/${messageId}.json`, {
      method: "PUT",
    }).then(() => {
      this.currentUserMembership.last_read_message_id = messageId;
    });
  }
}

export function createDirectMessageChannelDraft() {
  return ChatChannel.create({
    isDraft: true,
    chatable_type: CHATABLE_TYPES.directMessageChannel,
    chatable: {
      users: [],
    },
  });
}
