import Component from "@glimmer/component";
import icon from "discourse-plugin/helpers/icon";
import { service } from "discourse-plugin/services";
import CurrentUser from "discourse-plugin/services/current-user";
import Site from "discourse-plugin/services/site";
import ChatService from "../services/chat.js";

export default class HeaderIcon extends Component {
  @service(ChatService) chat;
  @service(CurrentUser) currentUser;
  @service(Site) site;

  get showUnreadIndicator() {
    return !this.currentUser.isInDoNotDisturb();
  }

  get icon() {
    if (this.site.desktopView) {
      return "desktop";
    } else {
      return "mobile-alt";
    }
  }

  <template>
    <a href="/chat" class="icon btn-flat active" title="Chat">
      {{icon this.icon}}
      {{#if this.showUnreadIndicator}}
        <div class="chat-channel-unread-indicator"></div>
      {{/if}}
    </a>
  </template>
}
