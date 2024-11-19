import { LinkTo } from "@ember/routing";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class ChatNavbarChannelTitle extends Component {
  @service chatStateManager;

  <template>
    {{#if @channel}}
      {{#if this.chatStateManager.isDrawerExpanded}}
        <LinkTo
          @route="chat.channel.info.settings"
          @models={{@channel.routeModels}}
          class="c-navbar__channel-title"
        >
          <ChannelTitle @channel={{@channel}} />
        </LinkTo>
      {{else}}
        <ChannelTitle @channel={{@channel}} />
      {{/if}}
    {{/if}}
  </template>
}
