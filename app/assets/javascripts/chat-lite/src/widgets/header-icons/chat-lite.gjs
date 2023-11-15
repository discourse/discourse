import { icon } from "discourse-plugin/helper";
import { service } from "discourse-plugin/service";
import Widget from "discourse-plugin/widget";
import ChatService from "../../services/chat";

export default class ChatLiteHeaderIcon extends Widget {
  @service(ChatService) chat;

  get isActive() {
    return this.chat.userCanChat;
  }

  <template>
    <li class="header-dropdown-toggle chat-header-icon">
      {{icon "birthday-cake"}}
    </li>
  </template>
}
