import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import { clipboardCopyAsync } from "discourse/lib/utilities";
import { not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import DeleteMessagesConfirm from "discourse/plugins/chat/discourse/components/chat/modal/delete-messages-confirm";
import ChatModalMoveMessageToChannel from "discourse/plugins/chat/discourse/components/chat/modal/move-message-to-channel";

const DELETE_COUNT_LIMIT = 200;

export default class ChatSelectionManager extends Component {
  @service("composer") topicComposer;
  @service router;
  @service modal;
  @service site;
  @service toasts;
  @service currentUser;
  @service("chat-api") api;

  get enableMove() {
    return this.args.enableMove ?? false;
  }

  get selectedMessageIds() {
    return this.args.messagesManager.selectedMessages.map(
      (message) => message.id
    );
  }

  get anyMessagesSelected() {
    return this.selectedMessageIds.length > 0;
  }

  get deleteCountLimitReached() {
    return this.selectedMessageIds.length > DELETE_COUNT_LIMIT;
  }

  get canDeleteMessages() {
    return this.selectedMessageIds.every((id) => {
      return this.canDeleteMessage(id);
    });
  }

  get deleteButtonTitle() {
    return i18n("chat.selection.delete", {
      selectionCount: this.selectedMessageIds.length,
      totalCount: DELETE_COUNT_LIMIT,
    });
  }

  canDeleteMessage(id) {
    const message = this.args.messagesManager?.findMessage(id);

    if (message) {
      const canDelete =
        this.currentUser.id === message.user.id
          ? message.channel?.canDeleteSelf
          : message.channel?.canDeleteOthers;

      return (
        canDelete &&
        !message.deletedAt &&
        message.channel?.canModifyMessages?.(this.currentUser)
      );
    }
  }

  @bind
  async generateQuote() {
    const { markdown } = await this.api.generateQuote(
      this.args.channel.id,
      this.selectedMessageIds
    );

    return new Blob([markdown], { type: "text/plain" });
  }

  @action
  cancelSelecting() {
    this.args.messagesManager.clearSelectedMessages();
    this.args.pane.cancelSelecting();
  }

  @action
  openMoveMessageModal() {
    this.modal.show(ChatModalMoveMessageToChannel, {
      model: {
        sourceChannel: this.args.channel,
        selectedMessageIds: this.selectedMessageIds,
      },
    });
  }

  @action
  openDeleteMessagesModal() {
    this.modal.show(DeleteMessagesConfirm, {
      model: {
        sourceChannel: this.args.channel,
        selectedMessageIds: this.selectedMessageIds,
      },
    });
  }

  @action
  async quoteMessages() {
    let quoteMarkdown;

    try {
      const quoteMarkdownBlob = await this.generateQuote();
      quoteMarkdown = await quoteMarkdownBlob.text();
    } catch (error) {
      popupAjaxError(error);
    }

    const openOpts = {};
    if (this.args.channel.isCategoryChannel) {
      openOpts.categoryId = this.args.channel.chatableId;
    }

    if (this.site.mobileView) {
      // go to the relevant chatable (e.g. category) and open the
      // composer to insert text
      if (this.args.channel.chatableUrl) {
        this.router.transitionTo(this.args.channel.chatableUrl);
      }

      await this.topicComposer.focusComposer({
        fallbackToNewTopic: true,
        insertText: quoteMarkdown,
        openOpts,
      });
    } else {
      // open the composer and insert text, reply to the current
      // topic if there is one, use the active draft if there is one
      const container = getOwner(this);
      const topic = container.lookup("controller:topic");
      await this.topicComposer.focusComposer({
        fallbackToNewTopic: true,
        topic: topic?.model,
        insertText: quoteMarkdown,
        openOpts,
      });
    }
  }

  @action
  async copyMessages() {
    try {
      if (!isTesting()) {
        // clipboard API throws errors in tests
        await clipboardCopyAsync(this.generateQuote);

        this.toasts.success({
          duration: "short",
          data: {
            message: i18n("chat.quote.copy_success"),
          },
        });
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div
      class="chat-selection-management"
      data-last-copy-successful={{this.lastCopySuccessful}}
    >
      <div class="chat-selection-management__buttons">
        <DButton
          class="btn-default"
          id="chat-quote-btn"
          @action={{this.quoteMessages}}
          @disabled={{not this.anyMessagesSelected}}
          @icon="quote-left"
          @label="chat.selection.quote_selection"
        />

        <DButton
          class="btn-default"
          id="chat-copy-btn"
          @action={{this.copyMessages}}
          @disabled={{not this.anyMessagesSelected}}
          @icon="copy"
          @label="chat.selection.copy"
        />

        {{#if this.enableMove}}
          <DButton
            class="btn-default"
            id="chat-move-to-channel-btn"
            @action={{this.openMoveMessageModal}}
            @disabled={{not this.anyMessagesSelected}}
            @icon="right-from-bracket"
            @label="chat.selection.move_selection_to_channel"
          />
        {{/if}}

        <DButton
          class="btn-default"
          id="chat-delete-btn"
          @action={{this.openDeleteMessagesModal}}
          @disabled={{or
            (not this.anyMessagesSelected)
            (not this.canDeleteMessages)
            this.deleteCountLimitReached
          }}
          @icon="trash-can"
          @translatedLabel={{this.deleteButtonTitle}}
        />

        <DButton
          class="btn-default cancel-btn"
          id="chat-cancel-selection-btn"
          @action={{this.cancelSelecting}}
          @icon="xmark"
          @label="chat.selection.cancel"
        />
      </div>
    </div>
  </template>
}
