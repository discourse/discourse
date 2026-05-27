import ChatPinnedMessagesListHeader from "discourse/plugins/chat/discourse/components/chat/pinned-messages-list/header";
import ChatPinnedMessagesList from "discourse/plugins/chat/discourse/components/chat-pinned-messages-list";

const ChatRoutesChannelPins = <template>
  <div class="c-routes --channel-pins c-channel-pins">
    <ChatPinnedMessagesListHeader @channel={{@channel}} />
    <ChatPinnedMessagesList
      @channel={{@channel}}
      @pinnedMessages={{@pinnedMessages}}
    />
  </div>
</template>;

export default ChatRoutesChannelPins;
