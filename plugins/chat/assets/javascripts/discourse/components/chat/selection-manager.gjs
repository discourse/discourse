import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import { clipboardCopyAsync } from "discourse/lib/utilities";
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

  get anyMessagesSelected() {
    return this.args.pane.selectedMessageIds.length > 0;
  }

  get deleteCountLimitReached() {
    return this.args.pane.selectedMessageIds.length > DELETE_COUNT_LIMIT;
  }

  get canDeleteMessages() {
    return this.args.pane.selectedMessageIds.every((id) => {
      return this.canDeleteMessage(id);
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

  get deleteButtonTitle() {
    return i18n("chat.selection.delete", {
      selectionCount: this.args.pane.selectedMessageIds.length,
      totalCount: DELETE_COUNT_LIMIT,
    });
  }

  @bind
  async generateQuote() {
    const { markdown } = await this.api.generateQuote(
      this.args.pane.channel.id,
      this.args.pane.selectedMessageIds
    );

    return new Blob([markdown], { type: "text/plain" });
  }

  @action
  openMoveMessageModal() {
    this.modal.show(ChatModalMoveMessageToChannel, {
      model: {
        sourceChannel: this.args.pane.channel,
        selectedMessageIds: this.args.pane.selectedMessageIds,
      },
    });
  }

  @action
  openDeleteMessagesModal() {
    this.modal.show(DeleteMessagesConfirm, {
      model: {
        sourceChannel: this.args.pane.channel,
        selectedMessageIds: this.args.pane.selectedMessageIds,
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
    if (this.args.pane.channel.isCategoryChannel) {
      openOpts.categoryId = this.args.pane.channel.chatableId;
    }

    if (this.site.mobileView) {
      // go to the relevant chatable (e.g. category) and open the
      // composer to insert text
      if (this.args.pane.channel.chatableUrl) {
        this.router.transitionTo(this.args.pane.channel.chatableUrl);
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
          duration: 3000,
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
          @icon="quote-left"
          @label="chat.selection.quote_selection"
          @disabled={{not this.anyMessagesSelected}}
          @action={{this.quoteMessages}}
          id="chat-quote-btn"
        />

        <DButton
          @icon="copy"
          @label="chat.selection.copy"
          @disabled={{not this.anyMessagesSelected}}
          @action={{this.copyMessages}}
          id="chat-copy-btn"
        />

        {{#if this.enableMove}}
          <DButton
            @icon="right-from-bracket"
            @label="chat.selection.move_selection_to_channel"
            @disabled={{not this.anyMessagesSelected}}
            @action={{this.openMoveMessageModal}}
            id="chat-move-to-channel-btn"
          />
        {{/if}}

        <DButton
          @icon="trash-can"
          @translatedLabel={{this.deleteButtonTitle}}
          @disabled={{or
            (not this.anyMessagesSelected)
            (not this.canDeleteMessages)
            this.deleteCountLimitReached
          }}
          @action={{this.openDeleteMessagesModal}}
          id="chat-delete-btn"
        />

        <DButton
          @icon="xmark"
          @label="chat.selection.cancel"
          @action={{@pane.cancelSelecting}}
          id="chat-cancel-selection-btn"
          class="btn-secondary cancel-btn"
        />
      </div>
    </div>
  </template>
}
