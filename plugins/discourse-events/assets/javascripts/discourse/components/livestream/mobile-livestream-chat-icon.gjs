import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import MobileEmbeddableChatModal from "./modal/mobile-embeddable-chat-modal";

export default class MobileLivestreamChatIcon extends Component {
  @service modal;
  @service embeddableChat;
  @service siteSettings;

  @action
  openLivestreamChat() {
    if (this.siteSettings.livestream_enable_modal_chat_on_mobile) {
      this.modal.show(MobileEmbeddableChatModal);
    } else {
      this.embeddableChat.toggleChatVisibility();
    }
  }

  <template>
    <li class="header-dropdown-toggle livestream-header-icon">
      <DButton
        @icon="comments"
        class="icon btn-flat"
        tabindex="0"
        @action={{this.openLivestreamChat}}
      />
    </li>
  </template>
}
