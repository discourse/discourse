import { hash } from "@ember/helper";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";

const ChatMessagesContainer = <template>
  <div
    class="chat-messages-container"
    {{dOnResize @didResizePane (hash delay=100 immediate=true)}}
  >
    {{yield}}
  </div>
</template>;

export default ChatMessagesContainer;
