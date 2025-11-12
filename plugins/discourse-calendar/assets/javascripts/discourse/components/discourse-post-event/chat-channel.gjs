import { LinkTo } from "@ember/routing";
import { optionalRequire } from "discourse/lib/utilities";
import { and } from "discourse/truth-helpers";

const ChannelTitle = optionalRequire(
  "discourse/plugins/chat/discourse/components/channel-title"
);

const DiscoursePostEventChatChannel = <template>
  {{#if (and @event.channel ChannelTitle)}}
    <section class="event__section event-chat-channel">
      <span></span>
      <LinkTo
        @route="chat.channel"
        @models={{@event.channel.routeModels}}
        class="chat-channel-link"
      >
        <ChannelTitle @channel={{@event.channel}} />
      </LinkTo>
    </section>
  {{/if}}
</template>;

export default DiscoursePostEventChatChannel;
