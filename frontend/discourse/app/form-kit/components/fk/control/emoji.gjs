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
      @btnClass="btn-emoji btn-default"
      @context={{@context}}
      @didSelectEmoji={{this.updateField}}
      @emoji={{@field.value}}
      @modalForMobile={{false}}
      @showCaret={{true}}
    />
  </template>
}
