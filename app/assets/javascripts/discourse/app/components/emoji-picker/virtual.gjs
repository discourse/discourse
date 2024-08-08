import Component from "@glimmer/component";
import EmojiPickerContent from "discourse/components/emoji-picker/content";

export default class EmojiPickerVirtual extends Component {
  <template>
    <EmojiPickerContent
      @close={{@close}}
      @term={{@data.term}}
      @didSelectEmoji={{@data.didSelectEmoji}}
    />
  </template>
}
