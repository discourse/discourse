import Component from "@ember/component";
import { action, computed } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import { clipboardCopyAsync } from "discourse/lib/utilities";
import { getOwner } from "discourse-common/lib/get-owner";
import { ajax } from "discourse/lib/ajax";
import { isTesting } from "discourse-common/config/environment";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";
import { MESSAGE_CONTEXT_THREAD } from "discourse/plugins/chat/discourse/components/chat-message";

export default class ChatSelectionManager extends Component {
  @service router;
  tagName = "";
  chatChannel = null;
  context = null;
  selectedMessageIds = null;
  chatCopySuccess = false;
  showChatCopySuccess = false;
  cancelSelecting = null;

  @computed("selectedMessageIds.length")
  get anyMessagesSelected() {
    return this.selectedMessageIds.length > 0;
  }

  @computed("chatChannel.isDirectMessageChannel", "chatChannel.canModerate")
  get showMoveMessageButton() {
    return (
      !this.context === MESSAGE_CONTEXT_THREAD &&
      !this.chatChannel.isDirectMessageChannel &&
      this.chatChannel.canModerate
    );
  }

  @bind
  async generateQuote() {
    const response = await ajax(
      getURL(`/chat/${this.chatChannel.id}/quote.json`),
      {
        data: { message_ids: this.selectedMessageIds },
        type: "POST",
      }
    );

    return new Blob([response.markdown], {
      type: "text/plain",
    });
  }

  @action
  openMoveMessageModal() {
    showModal("chat-message-move-to-channel-modal").setProperties({
      sourceChannel: this.chatChannel,
      selectedMessageIds: this.selectedMessageIds,
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

    const container = getOwner(this);
    const composer = container.lookup("controller:composer");
    const openOpts = {};

    if (this.chatChannel.isCategoryChannel) {
      openOpts.categoryId = this.chatChannel.chatable_id;
    }

    if (this.site.mobileView) {
      // go to the relevant chatable (e.g. category) and open the
      // composer to insert text
      if (this.chatChannel.chatable_url) {
        this.router.transitionTo(this.chatChannel.chatable_url);
      }

      await composer.focusComposer({
        fallbackToNewTopic: true,
        insertText: quoteMarkdown,
        openOpts,
      });
    } else {
      // open the composer and insert text, reply to the current
      // topic if there is one, use the active draft if there is one
      const topic = container.lookup("controller:topic");
      await composer.focusComposer({
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
      this.set("chatCopySuccess", false);

      if (!isTesting()) {
        // clipboard API throws errors in tests
        await clipboardCopyAsync(this.generateQuote);
        this.set("chatCopySuccess", true);
      }

      this.set("showChatCopySuccess", true);

      schedule("afterRender", () => {
        const element = document.querySelector(".chat-selection-message");
        element?.addEventListener("animationend", () => {
          if (this.isDestroying || this.isDestroyed) {
            return;
          }

          this.set("showChatCopySuccess", false);
        });
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
