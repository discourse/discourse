import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import EmbeddableChatChannel from "../../components/livestream/embeddable-chat-channel";

export default class EmbedableChatChannelConnector extends Component {
  @service embeddableChat;
  @service siteSettings;
  @service capabilities;
  @service router;

  get shouldRender() {
    const mobileViewport =
      !this.siteSettings.livestream_enable_modal_chat_on_mobile &&
      !this.capabilities.viewport.lg;

    if (!this.siteSettings.chat_enabled) {
      return false;
    }

    if (this.isZoomRoute) {
      return false;
    }

    return this.embeddableChat.canRenderChatChannel(mobileViewport);
  }

  get isZoomRoute() {
    return this.router.currentRouteName === "topic-zoom";
  }

  <template>
    {{#if this.embeddableChat.useLivestreamLayout}}
      {{bodyClass "livestream-topic"}}
    {{/if}}
    {{#if this.shouldRender}}
      <EmbeddableChatChannel
        @chatChannelId={{this.embeddableChat.chatChannelId}}
      />
    {{/if}}
  </template>
}
