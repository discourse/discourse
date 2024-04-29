import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import ChatScrollableList from "../modifiers/chat/scrollable-list";

const ChatMessagesScroller = <template>
  <div
    class="chat-messages-scroller popper-viewport"
    {{didInsert @onRegisterScroller}}
    {{ChatScrollableList
      (hash onScroll=@onScroll onScrollEnd=@onScrollEnd reverse=true)
    }}
  >
    {{yield}}
  </div>
</template>;

export default ChatMessagesScroller;
