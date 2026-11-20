import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import ChatScrollableList from "../modifiers/chat/scrollable-list.js";

const ChatMessagesScroller = <template>
  <div
    class="chat-messages-scroller"
    {{didInsert @onRegisterScroller}}
    {{this.setupLock}}
    {{ChatScrollableList
      (hash onScroll=@onScroll onScrollEnd=@onScrollEnd reverse=true)
    }}
  >
    {{yield}}
  </div>
</template>;

export default ChatMessagesScroller;
