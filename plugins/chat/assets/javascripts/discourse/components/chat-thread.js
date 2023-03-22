import Component from "@glimmer/component";
import { cloneJSON } from "discourse-common/lib/object";
import ChatMessageDraft from "discourse/plugins/chat/discourse/models/chat-message-draft";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind, debounce } from "discourse-common/utils/decorators";
import I18n from "I18n";
import { inject as service } from "@ember/service";
import ChatMessageActions from "discourse/plugins/chat/discourse/lib/chat-message-actions";

const PAGE_SIZE = 50;

export default class ChatThreadPanel extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service router;
  @service chatApi;
  @service chatComposerPresenceManager;
  @service chatChannelThreadComposer;
  @service appEvents;

  @tracked loading;
  @tracked loadingMorePast;

  constructor() {
    super(...arguments);
    this.messageActionsHandler = new ChatMessageActions(this.currentUser);
  }

  get thread() {
    return this.channel.activeThread;
  }

  get channel() {
    return this.chat.activeChannel;
  }

  get title() {
    if (this.thread.title) {
      this.thread.escapedTitle;
    }

    return I18n.t("chat.threads.op_said");
  }

  @action
  loadMessages() {
    if (this.args.targetMessageId) {
      this.requestedTargetMessageId = parseInt(this.args.targetMessageId, 10);
    }

    // TODO (martin) Loading/scrolling to selected messagew
    // this.highlightOrFetchMessage(this.requestedTargetMessageId);
    // if (this.requestedTargetMessageId) {
    // } else {
    this.fetchMessages();
    // }
  }

  get _selfDeleted() {
    return this.isDestroying || this.isDestroyed;
  }

  @debounce(100)
  fetchMessages() {
    if (this._selfDeleted) {
      return;
    }

    this.loadingMorePast = true;
    this.loading = true;
    this.thread.messagesManager.clearMessages();

    const findArgs = { pageSize: PAGE_SIZE };

    // TODO (martin) Find arguments for last read etc.
    // const fetchingFromLastRead = !options.fetchFromLastMessage;
    // if (this.requestedTargetMessageId) {
    //   findArgs["targetMessageId"] = this.requestedTargetMessageId;
    // } else if (fetchingFromLastRead) {
    //   findArgs["targetMessageId"] = this._getLastReadId();
    // }
    //
    findArgs.threadId = this.thread.id;

    return this.chatApi
      .messages(this.channel.id, findArgs)
      .then((results) => {
        if (this._selfDeleted || this.channel.id !== results.meta.channel_id) {
          this.router.transitionTo(
            "chat.channel",
            "-",
            results.meta.channel_id
          );
        }

        const [messages, meta] = this.afterFetchCallback(this.channel, results);
        this.thread.messagesManager.addMessages(messages);

        // TODO (martin) ECHO MODE
        this.channel.messagesManager.addMessages(messages);

        // TODO (martin) details needed for thread??
        this.thread.details = meta;

        // TODO (martin) Scrolling to particular messages
        // if (this.requestedTargetMessageId) {
        //   this.scrollToMessage(findArgs["targetMessageId"], {
        //     highlight: true,
        //   });
        // } else if (fetchingFromLastRead) {
        //   this.scrollToMessage(findArgs["targetMessageId"]);
        // } else if (messages.length) {
        //   this.scrollToMessage(messages.lastObject.id);
        // }
      })
      .catch(this.#handleErrors)
      .finally(() => {
        if (this._selfDeleted) {
          return;
        }

        this.requestedTargetMessageId = null;
        this.loading = false;
        this.loadingMorePast = false;

        // this.fillPaneAttempt();
      });
  }

  @bind
  afterFetchCallback(channel, results) {
    const messages = [];
    let foundFirstNew = false;

    results.chat_messages.forEach((messageData) => {
      // If a message has been hidden it is because the current user is ignoring
      // the user who sent it, so we want to unconditionally hide it, even if
      // we are going directly to the target
      if (this.currentUser.ignored_users) {
        messageData.hidden = this.currentUser.ignored_users.includes(
          messageData.user.username
        );
      }

      if (this.requestedTargetMessageId === messageData.id) {
        messageData.expanded = !messageData.hidden;
      } else {
        messageData.expanded = !(messageData.hidden || messageData.deleted_at);
      }

      // newest has to be in after fetcg callback as we don't want to make it
      // dynamic or it will make the pane jump around, it will disappear on reload
      if (
        !foundFirstNew &&
        messageData.id > channel.currentUserMembership.last_read_message_id
      ) {
        foundFirstNew = true;
        messageData.newest = true;
      }

      messages.push(ChatMessage.create(channel, messageData));
    });

    return [messages, results.meta];
  }

  @action
  sendMessage(message, uploads = []) {
    // TODO (martin) For desktop notifications
    // resetIdle()
    if (this.sendingLoading) {
      return;
    }

    this.sendingLoading = true;
    this.channel.draft = ChatMessageDraft.create();

    // TODO (martin) Handling case when channel is not followed???? IDK if we
    // even let people send messages in threads without this, seems weird.

    const stagedMessage = ChatMessage.createStagedMessage(this.channel, {
      message,
      created_at: new Date(),
      uploads: cloneJSON(uploads),
      user: this.currentUser,
      thread_id: this.thread.id,
    });

    this.thread.messagesManager.addMessages([stagedMessage]);

    // TODO (martin) Scrolling!!
    // if (!this.channel.canLoadMoreFuture) {
    //   this.scrollToBottom();
    // }

    return this.chatApi
      .sendMessage(this.channel.id, {
        message: stagedMessage.message,
        in_reply_to_id: stagedMessage.inReplyTo?.id,
        staged_id: stagedMessage.stagedId,
        upload_ids: stagedMessage.uploads.map((upload) => upload.id),
        thread_id: stagedMessage.threadId,
      })
      .then(() => {
        // TODO (martin) Scrolling!!
        // this.scrollToBottom();
      })
      .catch((error) => {
        this.#onSendError(stagedMessage.stagedId, error);
      })
      .finally(() => {
        if (this._selfDeleted) {
          return;
        }
        this.sendingLoading = false;
        this.#resetAfterSend();
      });
  }

  @action
  editMessage() {}
  // editMessage(chatMessage, newContent, uploads) {}

  @action
  editLastMessageRequested() {}

  #handleErrors(error) {
    switch (error?.jqXHR?.status) {
      case 429:
      case 404:
        popupAjaxError(error);
        break;
      default:
        throw error;
    }
  }

  #onSendError(stagedId, error) {
    const stagedMessage =
      this.thread.messagesManager.findStagedMessage(stagedId);
    if (stagedMessage) {
      if (error.jqXHR?.responseJSON?.errors?.length) {
        stagedMessage.error = error.jqXHR.responseJSON.errors[0];
      } else {
        this.chat.markNetworkAsUnreliable();
        stagedMessage.error = "network_error";
      }
    }

    this.#resetAfterSend();
  }

  #resetAfterSend() {
    if (this._selfDeleted) {
      return;
    }

    this.chatChannelThreadComposer.replyToMsg = null;
    this.chatChannelThreadComposer.editingMessage = null;
    this.chatComposerPresenceManager.notifyState(this.channel.id, false);
    this.appEvents.trigger("chat-composer:reply-to-set", null);
  }
}
