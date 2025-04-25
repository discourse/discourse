import ChatDirectMessageButton from "../../components/chat/direct-message-button";

const ChatButton = <template>
  {{#if @outletArgs.model.can_chat_user}}
    <li class="user-card-below-message-button chat-button">
      <ChatDirectMessageButton @user={{@outletArgs.model}} />
    </li>
  {{/if}}
</template>;

export default ChatButton;
