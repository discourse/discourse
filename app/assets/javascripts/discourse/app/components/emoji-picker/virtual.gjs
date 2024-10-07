import EmojiPickerContent from "discourse/components/emoji-picker/content";

const EmojiPickerVirtual = <template>
  <EmojiPickerContent
    @close={{@close}}
    @term={{@data.term}}
    @didSelectEmoji={{@data.didSelectEmoji}}
  />
</template>;

export default EmojiPickerVirtual;
