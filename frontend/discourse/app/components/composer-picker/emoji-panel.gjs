import EmojiPickerContent from "discourse/components/emoji-picker/content";

const EmojiPanel = <template>
  <EmojiPickerContent
    @close={{@close}}
    @context={{@context}}
    @didSelectEmoji={{@onSelect}}
    @term={{@term}}
  />
</template>;

export default EmojiPanel;
