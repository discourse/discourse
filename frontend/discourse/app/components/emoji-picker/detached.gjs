import EmojiPickerContent from "discourse/components/emoji-picker/content";

const EmojiPickerDetached = <template>
  <EmojiPickerContent
    @close={{@close}}
    @context={{@data.context}}
    @didSelectEmoji={{@data.didSelectEmoji}}
    @term={{@data.term}}
  />
</template>;

export default EmojiPickerDetached;
