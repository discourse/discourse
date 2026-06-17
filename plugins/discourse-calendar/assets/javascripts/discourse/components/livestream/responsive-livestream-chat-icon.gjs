import Component from "@glimmer/component";
import { service } from "@ember/service";
import MobileLivestreamChatIcon from "./mobile-livestream-chat-icon";

export default class ResponsiveLivestreamChatIcon extends Component {
  @service capabilities;
  @service siteSettings;
  @service embeddableChat;

  get shouldShow() {
    return (
      this.siteSettings.livestream_enabled &&
      !this.capabilities.viewport.lg &&
      this.embeddableChat.chatChannelId
    );
  }

  <template>
    {{#if this.shouldShow}}
      <MobileLivestreamChatIcon />
    {{/if}}
  </template>
}
