import replaceEmoji from "discourse/helpers/replace-emoji";

const ChatEmojiAvatar = <template>
  <div class="chat-emoji-avatar">
    <div class="chat-emoji-avatar-container">
      {{replaceEmoji @emoji}}
    </div>
  </div>
</template>;

export default ChatEmojiAvatar;
