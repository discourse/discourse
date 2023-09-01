import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { headerOffset } from "discourse/lib/offset-calculator";
import { createPopper } from "@popperjs/core";
import ChatEmojiPicker from "discourse/plugins/chat/discourse/components/chat-emoji-picker";
import { modifier } from "ember-modifier";

export default class ChatChannelMessageEmojiPicker extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
    <ChatEmojiPicker
      @context="chat-channel-message"
      @didInsert={{this.didInsert}}
      @willDestroy={{this.willDestroy}}
      @didSelectEmoji={{this.didSelectEmoji}}
      @class="hidden"
      {{this.listenToBodyScroll}}
    />
  </template>

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

  @action
  willDestroy() {
    this._popper?.destroy();
  }
}
