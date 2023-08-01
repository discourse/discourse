import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import { getOwner } from "@ember/application";
import { schedule } from "@ember/runloop";
import { createPopper } from "@popperjs/core";
import chatMessageContainer from "discourse/plugins/chat/discourse/lib/chat-message-container";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

const MSG_ACTIONS_VERTICAL_PADDING = -10;
const FULL = "full";
const REDUCED = "reduced";
const REDUCED_WIDTH_THRESHOLD = 500;

export default class ChatMessageActionsDesktop extends Component {
  @service chat;
  @service chatEmojiPickerManager;
  @service site;

  @tracked size = FULL;

  popper = null;

  get message() {
    return this.chat.activeMessage.model;
  }

  get context() {
    return this.chat.activeMessage.context;
  }

  get messageInteractor() {
    return new ChatMessageInteractor(
      getOwner(this),
      this.message,
      this.context
    );
  }

  get shouldRenderFavoriteReactions() {
    return this.size === FULL;
  }

  @action
  onWheel() {
    // prevents menu to stop scroll on the list of messages
    this.chat.activeMessage = null;
  }

  @action
  onMouseleave(event) {
    // if the mouse is leaving the actions menu for the actual menu, don't close it
    // this will avoid the menu rerendering
    if (
      (event.toElement || event.relatedTarget)?.closest(
        ".chat-message-container"
      )
    ) {
      return;
    }

    this.chat.activeMessage = null;
  }

  @action
  setup(element) {
    this.popper?.destroy();

    schedule("afterRender", () => {
      const messageContainer = chatMessageContainer(
        this.message.id,
        this.context
      );

      if (!messageContainer) {
        return;
      }

      const viewport = messageContainer.closest(".popper-viewport");
      this.size =
        viewport.clientWidth < REDUCED_WIDTH_THRESHOLD ? REDUCED : FULL;

      if (!messageContainer) {
        return;
      }

      this.popper = createPopper(messageContainer, element, {
        placement: "top-end",
        strategy: "fixed",
        modifiers: [
          {
            name: "flip",
            enabled: true,
            options: {
              boundary: viewport,
              fallbackPlacements: ["bottom-end"],
            },
          },
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

  @action
  teardown() {
    this.popper?.destroy();
    this.popper = null;
  }
}
