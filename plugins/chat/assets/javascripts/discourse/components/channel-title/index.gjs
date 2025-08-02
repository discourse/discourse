import concatClass from "discourse/helpers/concat-class";
import ChannelIcon from "discourse/plugins/chat/discourse/components/channel-icon";
import ChannelName from "discourse/plugins/chat/discourse/components/channel-name";

const ChatChannelTitle = <template>
  <div
    class={{concatClass
      "chat-channel-title"
      (if @channel.isDirectMessageChannel "is-dm" "is-category")
    }}
  >
    <ChannelIcon @channel={{@channel}} />
    <ChannelName @channel={{@channel}} />

    {{#if @isUnread}}
      <div class="unread-indicator {{if @isUrgent '-urgent'}}"></div>
    {{/if}}

    {{#if (has-block)}}
      {{yield}}
    {{/if}}
  </div>
</template>;

export default ChatChannelTitle;
