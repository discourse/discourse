import { action } from "@ember/object";
import EmojiPicker from "discourse/components/emoji-picker";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";

export default class FKControlEmoji extends FKBaseControl {
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
