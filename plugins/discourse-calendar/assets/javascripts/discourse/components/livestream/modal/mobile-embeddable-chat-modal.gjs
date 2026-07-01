import Component from "@glimmer/component";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DModal from "discourse/ui-kit/d-modal";
import EmbeddableChatChannel from "../embeddable-chat-channel";

export default class MobileEmbeddableChatModal extends Component {
  @service embeddableChat;
  @service capabilities;

  checkAndCloseModal = () => {
    if (this.capabilities.viewport.lg) {
      this.args.closeModal();
    }
  };

  get isMobileViewport() {
    return !this.capabilities.viewport.lg;
  }

  get shouldRender() {
    return this.embeddableChat.canRenderChatChannel(this.isMobileViewport);
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="livestream-chat-modal"
      @hideHeader={{true}}
      {{didUpdate this.checkAndCloseModal this.capabilities.viewport.lg}}
    >
      <:body>
        {{#if this.shouldRender}}
          <EmbeddableChatChannel
            @chatChannelId={{this.embeddableChat.chatChannelId}}
            @onClose={{@closeModal}}
          />
        {{/if}}
      </:body>
    </DModal>
  </template>
}
