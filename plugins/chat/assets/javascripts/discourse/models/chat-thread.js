import { getOwner } from "discourse-common/lib/get-owner";
import ChatMessagesManager from "discourse/plugins/chat/discourse/lib/chat-messages-manager";
import User from "discourse/models/user";
import { escapeExpression } from "discourse/lib/utilities";
import { tracked } from "@glimmer/tracking";
import guid from "pretty-text/guid";

export const THREAD_STATUSES = {
  open: "open",
  readOnly: "read_only",
  closed: "closed",
  archived: "archived",
};

export default class ChatThread {
  @tracked title;
  @tracked status;

  messagesManager = new ChatMessagesManager(getOwner(this));

  constructor(args = {}) {
    this.title = args.title;
    this.id = args.id;
    this.channelId = args.channel_id;
    this.status = args.status;

    this.originalMessageUser = this.#initUserModel(args.original_message_user);
    this.originalMessage = args.original_message;
    this.originalMessage.user = this.originalMessageUser;
  }

  stageMessage(message) {
    message.id = guid();
    message.staged = true;
    message.draft = false;
    message.createdAt ??= moment.utc().format();
    message.cook();

    this.messagesManager.addMessages([message]);
  }

  get messages() {
    return this.messagesManager.messages;
  }

  set messages(messages) {
    this.messagesManager.messages = messages;
  }

  get selectedMessages() {
    return this.messages.filter((message) => message.selected);
  }

  get escapedTitle() {
    return escapeExpression(this.title);
  }

  #initUserModel(user) {
    if (!user || user instanceof User) {
      return user;
    }

    return User.create(user);
  }
}
