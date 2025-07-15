import { LinkTo } from "@ember/routing";
import { and } from "truth-helpers";
import { optionalRequire } from "discourse/lib/utilities";

const ChannelTitle = optionalRequire(
  "discourse/plugins/chat/discourse/components/channel-title"
);

const DiscoursePostEventChatChannel = <template>
  {{#if (and @event.channel ChannelTitle)}}
    <section class="event__section event-chat-channel">
      <span></span>
      <LinkTo @route="chat.channel" @models={{@event.channel.routeModels}}>
        <ChannelTitle @channel={{@event.channel}} />
      </LinkTo>
    </section>
  {{/if}}
</template>;

export default DiscoursePostEventChatChannel;
