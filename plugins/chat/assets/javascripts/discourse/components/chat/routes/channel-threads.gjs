import ChatThreadListHeader from "discourse/plugins/chat/discourse/components/chat/thread-list/header";
import ChatThreadList from "discourse/plugins/chat/discourse/components/chat-thread-list";

const ChatRoutesChannelThreads = <template>
  <div class="c-routes --channel-threads">
    <ChatThreadListHeader @channel={{@channel}} />
    <ChatThreadList @channel={{@channel}} @includeHeader={{true}} />
  </div>
</template>;

export default ChatRoutesChannelThreads;
