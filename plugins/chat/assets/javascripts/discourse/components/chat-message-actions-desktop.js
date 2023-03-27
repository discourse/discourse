import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import { getOwner } from "@ember/application";
import { MESSAGE_CONTEXT_THREAD } from "discourse/plugins/chat/discourse/components/chat-message";
import { schedule } from "@ember/runloop";
import { createPopper } from "@popperjs/core";
const MSG_ACTIONS_VERTICAL_PADDING = -10;

export default class ChatMessageActionsDesktop extends Component {
  @service chat;
  @service chatStateManager;
  @service site;

  popper = null;

  get message() {
    return this.chat.activeMessage.model;
  }

  get context() {
    return this.chat.activeMessage.context;
  }

  get messageInteractor() {
    const activeMessage = this.chat.activeMessage;

    return new ChatMessageInteractor(
      getOwner(this),
      activeMessage.model,
      activeMessage.context
    );
  }

  setupPopper(element) {
    schedule("afterRender", () => {
      let selector;

      if (this.context === MESSAGE_CONTEXT_THREAD) {
        selector = `.chat-thread .chat-message-container[data-id="${this.message.model.id}"]`;
      } else {
        selector = `.chat-live-pane .chat-message-container[data-id="${this.message.model.id}"]`;
      }

      this.popper = createPopper(document.querySelector(selector), element, {
        placement: "top-end",
        strategy: "fixed",
        modifiers: [
          { name: "hide", enabled: true },
          { name: "eventListeners", options: { scroll: false } },
          {
            name: "offset",
            options: { offset: [-2, MSG_ACTIONS_VERTICAL_PADDING] },
          },
        ],
      });
    });
  }

  teardownPopper() {
    this.popper?.destroy();
  }
}
