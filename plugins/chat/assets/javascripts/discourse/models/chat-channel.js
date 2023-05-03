import RestModel from "discourse/models/rest";
import User from "discourse/models/user";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";
import { ajax } from "discourse/lib/ajax";
import { escapeExpression } from "discourse/lib/utilities";
import { tracked } from "@glimmer/tracking";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";
import ChatThreadsManager from "discourse/plugins/chat/discourse/lib/chat-threads-manager";
import ChatMessagesManager from "discourse/plugins/chat/discourse/lib/chat-messages-manager";
import { getOwner } from "discourse-common/lib/get-owner";
import guid from "pretty-text/guid";
import ChatThread from "discourse/plugins/chat/discourse/models/chat-thread";

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

export default class ChatChannel extends RestModel {
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

  threadsManager = new ChatThreadsManager(getOwner(this));
  messagesManager = new ChatMessagesManager(getOwner(this));

  findIndexOfMessage(message) {
    return this.messages.findIndex((m) => m.id === message.id);
  }

  get messages() {
    return this.messagesManager.messages;
  }

  set messages(messages) {
    this.messagesManager.messages = messages;
  }

  get canLoadMoreFuture() {
    return this.messagesManager.canLoadMoreFuture;
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

  get selectedMessages() {
    return this.messages.filter((message) => message.selected);
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

  createStagedThread(message) {
    const clonedMessage = message.duplicate();

    const thread = new ChatThread(this, {
      id: guid(),
      original_message: message,
      staged: true,
      created_at: moment.utc().format(),
    });

    clonedMessage.thread = thread;
    this.threadsManager.store(this, thread);
    thread.messagesManager.addMessages([clonedMessage]);

    return thread;
  }

  stageMessage(message) {
    message.id = guid();
    message.staged = true;
    message.draft = false;
    message.createdAt ??= moment.utc().format();
    message.cook();

    if (message.inReplyTo) {
      if (!message.inReplyTo.thread) {
        message.inReplyTo.threadId = guid();
        message.inReplyTo.threadReplyCount = 1;
      }

      if (!this.threadingEnabled) {
        this.messagesManager.addMessages([message]);
      }
    } else {
      this.messagesManager.addMessages([message]);
    }
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

    // TODO (martin) Change this to use chatApi service once we change this
    // class not to use RestModel
    return ajax(`/chat/api/channels/${this.id}/read/${messageId}`, {
      method: "PUT",
    });
  }
}

ChatChannel.reopenClass({
  create(args) {
    args = args || {};

    this._initUserModels(args);
    this._initUserMembership(args);

    this._remapKey(args, "chatable_type", "chatableType");
    this._remapKey(args, "memberships_count", "membershipsCount");
    this._remapKey(args, "last_message_sent_at", "lastMessageSentAt");
    this._remapKey(args, "threading_enabled", "threadingEnabled");

    return this._super(args);
  },

  _remapKey(obj, oldKey, newKey) {
    delete Object.assign(obj, { [newKey]: obj[oldKey] })[oldKey];
  },

  _initUserModels(args) {
    if (args.chatable?.users?.length) {
      for (let i = 0; i < args.chatable?.users?.length; i++) {
        const userData = args.chatable.users[i];
        args.chatable.users[i] = User.create(userData);
      }
    }
  },

  _initUserMembership(args) {
    if (args.currentUserMembership instanceof UserChatChannelMembership) {
      return;
    }

    args.currentUserMembership = UserChatChannelMembership.create(
      args.current_user_membership || {
        following: false,
        muted: false,
        unread_count: 0,
        unread_mentions: 0,
      }
    );

    delete args.current_user_membership;
  },
});

export function createDirectMessageChannelDraft() {
  return ChatChannel.create({
    isDraft: true,
    chatable_type: CHATABLE_TYPES.directMessageChannel,
    chatable: {
      users: [],
    },
  });
}
