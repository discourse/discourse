import Component from "@ember/component";
import { action } from "@ember/object";
import { createPopper } from "@popperjs/core";
import { schedule } from "@ember/runloop";

const MSG_ACTIONS_PADDING = 2;

export default Component.extend({
  tagName: "",

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
          `.chat-msgactions-hover[data-id="${this.message.id}"] .chat-msgactions`
        ),
        {
          placement: "right-start",
          modifiers: [
            { name: "hide", enabled: true },
            {
              name: "offset",
              options: {
                offset: ({ popper, placement }) => {
                  return [
                    MSG_ACTIONS_PADDING,
                    -(placement.includes("left") || placement.includes("right")
                      ? popper.width + MSG_ACTIONS_PADDING
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
