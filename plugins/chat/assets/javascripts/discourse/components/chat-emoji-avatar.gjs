import replaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

const ChatEmojiAvatar = <template>
  <div class="chat-emoji-avatar">
    <div class="chat-emoji-avatar-container">
      {{replaceEmoji @emoji}}
    </div>
  </div>
</template>;

export default ChatEmojiAvatar;
