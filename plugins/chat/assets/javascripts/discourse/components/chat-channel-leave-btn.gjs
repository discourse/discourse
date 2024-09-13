import Component from "@glimmer/component";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import DButton from "discourse/components/d-button";

export default class ChatChannelLeaveBtn extends Component {
  @service chat;
  @service site;

  get shouldRender() {
    return this.site.desktopView && isPresent(this.args.channel);
  }

  get leaveChatTitleKey() {
    if (this.args.channel.isDirectMessageChannel) {
      return "chat.direct_messages.leave";
    } else {
      return "chat.leave";
    }
  }

  <template>
    {{#if this.shouldRender}}
      <DButton
        @icon="xmark"
        @action={{@onLeaveChannel}}
        @title={{this.leaveChatTitleKey}}
        class="btn-flat chat-channel-leave-btn"
      />
    {{/if}}
  </template>
}
