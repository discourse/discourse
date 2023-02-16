import Component from "@ember/component";
import { action } from "@ember/object";
import { createPopper } from "@popperjs/core";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";

const MSG_ACTIONS_VERTICAL_PADDING = -10;

export default Component.extend({
  tagName: "",

  chatStateManager: service(),

  messageActions: null,

  didReceiveAttrs() {
    this._super(...arguments);

    this.popper?.destroy();

    schedule("afterRender", () => {
      this.popper = createPopper(
        document.querySelector(
          `.chat-message-container[data-id="${this.message.id}"]`
        ),
        document.querySelector(
          `.chat-message-actions-container[data-id="${this.message.id}"] .chat-message-actions`
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
  },

  @action
  handleSecondaryButtons(id) {
    if (id === "copyLinkToMessage") {
      return this.messageActionsHandler.copyLink(this.message);
    }

    if (id === "selectMessage") {
      return this.messageActionsHandler.selectMessage(this.message, true);
    }

    this.messageActions?.[id]?.();
  },
});
