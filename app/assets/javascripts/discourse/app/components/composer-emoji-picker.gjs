import EmojiPicker from "discourse/components/emoji-picker";

const ComposerEmojiPicker = <template>
  <EmojiPicker
    @btnClass={{@button.className}}
    @didSelectEmoji={{@button.action}}
  />
</template>;

export default ComposerEmojiPicker;
