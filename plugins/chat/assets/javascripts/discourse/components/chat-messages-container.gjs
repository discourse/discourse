import { hash } from "@ember/helper";
import ChatOnResize from "../modifiers/chat/on-resize";

const ChatMessagesContainer = <template>
  <div
    class="chat-messages-container"
    {{ChatOnResize @didResizePane (hash delay=100 immediate=true)}}
  >
    {{yield}}
  </div>
</template>;

export default ChatMessagesContainer;
