import Component from "@glimmer/component";
import { action } from "@ember/object";
import { clipboardCopyAsync } from "discourse/lib/utilities";
import { getOwner } from "discourse-common/lib/get-owner";
import { isTesting } from "discourse-common/config/environment";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import ChatModalMoveMessageToChannel from "discourse/plugins/chat/discourse/components/chat/modal/move-message-to-channel";

export default class ChatSelectionManager extends Component {
  @service("composer") topicComposer;
  @service router;
  @service modal;
  @service site;
  @service("chat-api") api;

  // NOTE: showCopySuccess is used to display the message which animates
  // after a delay. The on-animation-end helper is not really usable in
  // system specs because it fires straight away, so we use lastCopySuccessful
  // with a data attr instead so it's not instantly mutated.
  @tracked showCopySuccess = false;
  @tracked lastCopySuccessful = false;

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
      this.lastCopySuccessful = false;
      this.showCopySuccess = false;

      if (!isTesting()) {
        // clipboard API throws errors in tests
        await clipboardCopyAsync(this.generateQuote);
      }

      this.showCopySuccess = true;
      this.lastCopySuccessful = true;
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
