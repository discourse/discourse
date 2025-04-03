import Component from "@glimmer/component";
import { action } from "@ember/object";
import EmojiPicker from "discourse/components/emoji-picker";

export default class FKControlEmoji extends Component {
  static controlType = "emoji";

  @action
  updateField(value) {
    this.args.field.set(value);
  }

  <template>
    <EmojiPicker
      @emoji={{@field.value}}
      @context={{@context}}
      @didSelectEmoji={{this.updateField}}
      @modalForMobile={{false}}
      @btnClass="btn-emoji"
    />
  </template>
}
