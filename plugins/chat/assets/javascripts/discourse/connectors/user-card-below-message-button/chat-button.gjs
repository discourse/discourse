import ChatDirectMessageButton from "../../components/chat/direct-message-button";

const ChatButton = <template>
  {{#if @outletArgs.user.can_chat_user}}
    <li class="user-card-below-message-button chat-button">
      <ChatDirectMessageButton @user={{@outletArgs.user}} @modal={{true}} />
    </li>
  {{/if}}
</template>;

export default ChatButton;
