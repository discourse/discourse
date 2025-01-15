import { tracked } from "@glimmer/tracking";
import guid from "pretty-text/guid";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import ChatMessagesManager from "discourse/plugins/chat/discourse/lib/chat-messages-manager";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatThreadPreview from "discourse/plugins/chat/discourse/models/chat-thread-preview";
import ChatTrackingState from "discourse/plugins/chat/discourse/models/chat-tracking-state";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";

export const THREAD_STATUSES = {
  open: "open",
  readOnly: "read_only",
  closed: "closed",
  archived: "archived",
};

export default class ChatThread {
  static create(channel, args = {}) {
    return new ChatThread(channel, args);
  }

  @tracked id;
  @tracked title;
  @tracked status;
  @tracked draft;
  @tracked staged;
  @tracked channel;
  @tracked originalMessage;
  @tracked lastMessageId;
  @tracked threadMessageBusLastId;
  @tracked replyCount;
  @tracked tracking;
  @tracked currentUserMembership;
  @tracked preview;
  @tracked force;

  messagesManager = new ChatMessagesManager(getOwnerWithFallback(this));

  constructor(channel, args = {}) {
    this.id = args.id;
    this.channel = channel;
    this.status = args.status;
    this.staged = args.staged;
    this.replyCount = args.reply_count;
    this.force = args.force;

    this.originalMessage = args.original_message
      ? ChatMessage.create(channel, args.original_message)
      : null;

    if (this.originalMessage) {
      this.originalMessage.thread = this;
    }

    this.lastMessageId = args.last_message_id;

    this.title = args.title;

    if (args.current_user_membership) {
      this.currentUserMembership = UserChatThreadMembership.create(
        args.current_user_membership
      );
    }

    this.tracking = new ChatTrackingState(getOwnerWithFallback(this));
    this.preview = ChatThreadPreview.create(args.preview);
  }

  resetDraft(user) {
    this.draft = ChatMessage.createDraftMessage(this.channel, {
      user,
      thread: this,
    });
  }

  async stageMessage(message) {
    message.id = guid();
    message.staged = true;
    message.processed = false;
    message.draft = false;
    message.createdAt = new Date();
    message.thread = this;

    this.messagesManager.addMessages([message]);
    message.manager = this.messagesManager;
  }

  get routeModels() {
    return [...this.channel.routeModels, this.id];
  }
}
