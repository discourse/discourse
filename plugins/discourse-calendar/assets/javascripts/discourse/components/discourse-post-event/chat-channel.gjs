import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { optionalRequire } from "discourse/lib/utilities";
import { and } from "discourse/truth-helpers";

export default class DiscoursePostEventChatChannel extends Component {
  get channelTitle() {
    return optionalRequire(
      "discourse/plugins/chat/discourse/components/channel-title"
    );
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
