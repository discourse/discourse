import Component from "@glimmer/component";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { lock, unlock } from "discourse/lib/body-scroll-lock";
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

  // DModal locks body scrolling while open, and on iOS that lock blocks touch
  // scrolling everywhere except elements registered with `lock()`. The modal
  // registers its own body, but the element that actually scrolls here is
  // chat's nested `.chat-messages-scroller`, so it has to be registered too —
  // as `reverseColumn`, since it's a column-reverse scroller.
  lockChatScroller = modifier((element) => {
    if (!this.capabilities.isIOS) {
      return;
    }

    let scroller = null;

    const lockScroller = () => {
      const currentScroller = element.querySelector(".chat-messages-scroller");

      if (currentScroller === scroller) {
        return;
      }

      if (scroller) {
        unlock(scroller);
      }

      scroller = currentScroller;

      if (scroller) {
        lock(scroller, { reverseColumn: true });
      }
    };

    lockScroller();

    const observer = new MutationObserver(lockScroller);
    observer.observe(element, { childList: true, subtree: true });

    return () => {
      observer.disconnect();

      if (scroller) {
        unlock(scroller);
      }
    };
  });

  get shouldRender() {
    return this.embeddableChat.canRenderChatChannel(
      this.embeddableChat.isMobileViewport
    );
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="livestream-chat-modal"
      @hideHeader={{true}}
      {{didUpdate this.checkAndCloseModal this.capabilities.viewport.lg}}
      {{this.lockChatScroller}}
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
