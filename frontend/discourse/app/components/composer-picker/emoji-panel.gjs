import EmojiPickerContent from "discourse/components/emoji-picker/content";

const EmojiPanel = <template>
  <EmojiPickerContent
    @didSelectEmoji={{@onSelect}}
    @close={{@close}}
    @context={{@context}}
    @term={{@term}}
  />
</template>;

export default EmojiPanel;
