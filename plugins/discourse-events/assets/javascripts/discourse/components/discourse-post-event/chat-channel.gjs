import { LinkTo } from "@ember/routing";
import { and } from "discourse/truth-helpers";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title" with {
  discourseImport: "optional",
};

export default <template>
  {{#if (and @event.channel ChannelTitle)}}
    <section class="event__section event-chat-channel">
      <span></span>
      <LinkTo
        class="chat-channel-link"
        @models={{@event.channel.routeModels}}
        @route="chat.channel"
      >
        <ChannelTitle @channel={{@event.channel}} />
      </LinkTo>
    </section>
  {{/if}}
</template>
