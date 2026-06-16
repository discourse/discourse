import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { and } from "discourse/truth-helpers";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

export default class DiscoursePostEventChatChannel extends Component {
  get channelTitle() {
    return ChannelTitle;
  }

  <template>
    {{#if (and @event.channel this.channelTitle)}}
      <section class="event__section event-chat-channel">
        <span></span>
        <LinkTo
          @route="chat.channel"
          @models={{@event.channel.routeModels}}
          class="chat-channel-link"
        >
          <this.channelTitle @channel={{@event.channel}} />
        </LinkTo>
      </section>
    {{/if}}
  </template>
}
