import EmojiPickerContent from "discourse/components/emoji-picker/content";

const EmojiPickerDetached = <template>
  <EmojiPickerContent
    @close={{@close}}
    @term={{@data.term}}
    @didSelectEmoji={{@data.didSelectEmoji}}
    @context={{@data.context}}
  />
</template>;

export default EmojiPickerDetached;
