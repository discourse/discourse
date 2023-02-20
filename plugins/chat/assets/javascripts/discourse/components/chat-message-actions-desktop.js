import Component from "@glimmer/component";
import { action } from "@ember/object";
import { createPopper } from "@popperjs/core";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";

const MSG_ACTIONS_VERTICAL_PADDING = -10;

export default class ChatMessageActionsDesktop extends Component {
  @service chatStateManager;

  popper = null;

  @action
  destroyPopper() {
    this.popper?.destroy();
    this.popper = null;
  }

  @action
  attachPopper() {
    this.destroyPopper();

    schedule("afterRender", () => {
      this.popper = createPopper(
        document.querySelector(
          `.chat-message-container[data-id="${this.args.message.id}"]`
        ),
        document.querySelector(
          `.chat-message-actions-container[data-id="${this.args.message.id}"] .chat-message-actions`
        ),
        {
          placement: "top-end",
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
  handleSecondaryButtons(id) {
    if (id === "copyLinkToMessage") {
      return this.args.messageActionsHandler.copyLink(this.args.message);
    }

    if (id === "selectMessage") {
      return this.args.messageActionsHandler.selectMessage(
        this.args.message,
        true
      );
    }

    this.args.messageActions?.[id]?.();
  }
}
