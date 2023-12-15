import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

export default class ChatNavbarChannelTitle extends Component {
  <template>
    {{#if @channel}}
      <LinkTo
        @route="chat.channel.info"
        @models={{@channel.routeModels}}
        class="c-navbar__channel-title"
      >
        <ChannelTitle @channel={{@channel}} />
      </LinkTo>
    {{/if}}
  </template>
}
