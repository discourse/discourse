import Component from "@glimmer/component";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopyAsync } from "discourse/lib/utilities";
import { isTesting } from "discourse-common/config/environment";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import ChatModalMoveMessageToChannel from "discourse/plugins/chat/discourse/components/chat/modal/move-message-to-channel";

export default class ChatSelectionManager extends Component {
  @service("composer") topicComposer;
  @service router;
  @service modal;
  @service site;
  @service toasts;
  @service("chat-api") api;

  get enableMove() {
    return this.args.enableMove ?? false;
  }

  get anyMessagesSelected() {
    return this.args.pane.selectedMessageIds.length > 0;
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
            message: I18n.t("chat.quote.copy_success"),
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
            @icon="sign-out-alt"
            @label="chat.selection.move_selection_to_channel"
            @disabled={{not this.anyMessagesSelected}}
            @action={{this.openMoveMessageModal}}
            id="chat-move-to-channel-btn"
          />
        {{/if}}

        <DButton
          @icon="times"
          @label="chat.selection.cancel"
          @action={{@pane.cancelSelecting}}
          id="chat-cancel-selection-btn"
          class="btn-secondary cancel-btn"
        />
      </div>
    </div>
  </template>
}
