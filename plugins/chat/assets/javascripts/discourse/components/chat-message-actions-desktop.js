import Component from "@ember/component";
import { action } from "@ember/object";
import { createPopper } from "@popperjs/core";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";

const MSG_ACTIONS_HORIZONTAL_PADDING = 2;
const MSG_ACTIONS_VERTICAL_PADDING = -28;

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
          placement: "right-start",
          modifiers: [
            { name: "hide", enabled: true },
            {
              name: "eventListeners",
              options: {
                scroll: false,
              },
            },
            {
              name: "offset",
              options: {
                offset: ({ popper, placement }) => {
                  return [
                    MSG_ACTIONS_VERTICAL_PADDING,
                    -(placement.includes("left") || placement.includes("right")
                      ? popper.width + MSG_ACTIONS_HORIZONTAL_PADDING
                      : popper.height),
                  ];
                },
              },
            },
          ],
        }
      );
    });
  },

  @action
  handleSecondaryButtons(id) {
    this.messageActions?.[id]?.();
  },
});
