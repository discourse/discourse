import ChatEmojiAvatar from "../../chat-emoji-avatar";
import ChatUserAvatar from "../../chat-user-avatar";

const Avatar = <template>
  <div class="chat-message-avatar">
    {{#if @message.chatWebhookEvent.emoji}}
      <ChatEmojiAvatar @emoji={{@message.chatWebhookEvent.emoji}} />
    {{else}}
      <ChatUserAvatar @user={{@message.user}} @avatarSize="medium" />
    {{/if}}
  </div>
</template>;

export default Avatar;
