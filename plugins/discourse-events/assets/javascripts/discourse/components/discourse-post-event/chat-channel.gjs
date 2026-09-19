import { LinkTo } from "@ember/routing";
import { and } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title" with {
  discourseImport: "optional",
};

export default <template>
  {{#if (and @event.channel ChannelTitle)}}
    <section class="event__section event-chat-channel">
      {{dIcon "comment"}}
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
