import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { createPopper } from "@popperjs/core";
import { modifier } from "ember-modifier";
import { headerOffset } from "discourse/lib/offset-calculator";
import ChatEmojiPicker from "discourse/plugins/chat/discourse/components/chat-emoji-picker";

export default class ChatChannelMessageEmojiPicker extends Component {
  @service site;
  @service chatEmojiPickerManager;

  context = "chat-channel-message";

  listenToBodyScroll = modifier(() => {
    const handler = () => {
      this.chatEmojiPickerManager.close();
    };

    document.addEventListener("scroll", handler);

    return () => {
      document.removeEventListener("scroll", handler);
    };
  });

  @action
  willDestroy() {
    super.willDestroy(...arguments);
    this._popper?.destroy();
  }

  @action
  didSelectEmoji(emoji) {
    this.chatEmojiPickerManager.picker?.didSelectEmoji(emoji);
    this.chatEmojiPickerManager.close();
  }

  @action
  didInsert(element) {
    if (this.site.mobileView) {
      element.classList.remove("hidden");
      return;
    }

    this._popper = createPopper(
      this.chatEmojiPickerManager.picker?.trigger,
      element,
      {
        placement: "top",
        modifiers: [
          {
            name: "eventListeners",
            options: { scroll: false, resize: false },
          },
          {
            name: "flip",
            options: { padding: { top: headerOffset() } },
          },
        ],
      }
    );

    element.classList.remove("hidden");
  }

  <template>
    <ChatEmojiPicker
      {{this.listenToBodyScroll}}
      @context="chat-channel-message"
      @didInsert={{this.didInsert}}
      @willDestroy={{this.willDestroy}}
      @didSelectEmoji={{this.didSelectEmoji}}
      class="hidden"
    />
  </template>
}
