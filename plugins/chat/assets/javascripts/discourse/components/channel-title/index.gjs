import concatClass from "discourse/helpers/concat-class";
import ChannelIcon from "discourse/plugins/chat/discourse/components/channel-icon";
import ChannelName from "discourse/plugins/chat/discourse/components/channel-name";

const ChatChannelTitle = <template>
  <span
    class={{concatClass
      "chat-channel-title"
      (if @channel.isDirectMessageChannel "is-dm" "is-category")
    }}
  >
    <ChannelIcon @channel={{@channel}} />
    <ChannelName @channel={{@channel}} />

    {{#if (has-block)}}
      {{yield}}
    {{/if}}
  </span>
</template>;

export default ChatChannelTitle;
