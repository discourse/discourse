import { getOwner } from "discourse-common/lib/get-owner";
import ChatMessageDraft from "discourse/plugins/chat/discourse/models/chat-message-draft";
import ChatMessagesManager from "discourse/plugins/chat/discourse/lib/chat-messages-manager";
import User from "discourse/models/user";
import { escapeExpression } from "discourse/lib/utilities";
import { tracked } from "@glimmer/tracking";

export const THREAD_STATUSES = {
  open: "open",
  readOnly: "read_only",
  closed: "closed",
  archived: "archived",
};

export default class ChatThread {
  @tracked title;
  @tracked status;
  @tracked isDraft = false;
  @tracked draft;

  messagesManager = new ChatMessagesManager(getOwner(this));

  constructor(args = {}) {
    this.title = args.title;
    this.id = args.id;
    this.channel_id = args.channel_id;
    this.status = args.status;

    this.originalMessageUser = this.#initUserModel(args.original_message_user);

    // TODO (martin) Not sure if ChatMessage is needed here, original_message
    // only has a small subset of message stuff.
    this.originalMessage = args.original_message;
    this.originalMessage.user = this.originalMessageUser;

    // TODO (martin) Drafts per thread?
    // if (this.currentUser.chat_drafts) {
    //   const storedDraft = this.currentUser.chat_drafts.find(
    //     (draft) => draft.channel_id === this.channel_id
    //   );
    //   this.draft = ChatMessageDraft.create(
    //     storedDraft ? JSON.parse(storedDraft.data) : null
    //   );
    // }
    this.draft = ChatMessageDraft.create(null);
  }

  get messages() {
    return this.messagesManager.messages;
  }

  set messages(messages) {
    this.messagesManager.messages = messages;
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
