import Component from "@glimmer/component";
import { service } from "@ember/service";
import MobileLivestreamChatIcon from "./mobile-livestream-chat-icon";

export default class ResponsiveLivestreamChatIcon extends Component {
  @service embeddableChat;

  get shouldShow() {
    return (
      this.embeddableChat.isMobileViewport && this.embeddableChat.chatChannelId
    );
  }

  <template>
    {{#if this.shouldShow}}
      <MobileLivestreamChatIcon />
    {{/if}}
  </template>
}
