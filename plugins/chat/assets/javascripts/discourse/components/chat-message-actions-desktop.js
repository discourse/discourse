import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import { getOwner } from "@ember/application";
import { schedule } from "@ember/runloop";
import { createPopper } from "@popperjs/core";
import chatMessageContainer from "discourse/plugins/chat/discourse/lib/chat-message-container";
import { action } from "@ember/object";

const MSG_ACTIONS_VERTICAL_PADDING = -10;

export default class ChatMessageActionsDesktop extends Component {
  @service chat;
  @service chatStateManager;
  @service chatEmojiPickerManager;
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

  @action
  setupPopper(element) {
    this.popper?.destroy();

    schedule("afterRender", () => {
      this.popper = createPopper(
        chatMessageContainer(this.message.id, this.context),
        element,
        {
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
        }
      );
    });
  }

  @action
  teardownPopper() {
    this.popper?.destroy();
  }
}
