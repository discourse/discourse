import { and, not } from "truth-helpers";
import ChatDirectMessageButton from "../../components/chat/direct-message-button";

const ChatButton = <template>
  {{#if
    (and @outletArgs.model.can_chat_user (not @outletArgs.model.isCurrent))
  }}
    <li class="user-card-below-message-button chat-button">
      <ChatDirectMessageButton @user={{@outletArgs.model}} />
    </li>
  {{/if}}
</template>;

export default ChatButton;
