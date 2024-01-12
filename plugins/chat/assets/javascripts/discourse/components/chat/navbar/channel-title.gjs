import { LinkTo } from "@ember/routing";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

const ChatNavbarChannelTitle = <template>
  {{#if @channel}}
    <LinkTo
      @route="chat.channel.info.members"
      @models={{@channel.routeModels}}
      class="c-navbar__channel-title"
    >
      <ChannelTitle @channel={{@channel}} />
    </LinkTo>
  {{/if}}
</template>;

export default ChatNavbarChannelTitle;
