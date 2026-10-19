import ChatEmojiAvatar from "../../chat-emoji-avatar.gjs";
import ChatUserAvatar from "../../chat-user-avatar.gjs";

const Avatar = <template>
  <div class="chat-message-avatar">
    {{#if @message.chatWebhookEvent.emoji}}
      <ChatEmojiAvatar @emoji={{@message.chatWebhookEvent.emoji}} />
    {{else}}
      <ChatUserAvatar
        @ariaHidden={{true}}
        @avatarSize="medium"
        @interactive={{@interactive}}
        @user={{@message.user}}
      />
    {{/if}}
  </div>
</template>;

export default Avatar;
