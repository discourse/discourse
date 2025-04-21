import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import EmojiPicker from "discourse/components/emoji-picker";
import concatClass from "discourse/helpers/concat-class";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";

export default class UserStatusPicker extends Component {
  @tracked isFocused = false;

  get emojiHtml() {
    return emojiUnescape(escapeExpression(`:${this.args.status.emoji}:`));
  }

  @action
  blur() {
    this.isFocused = false;
  }

  @action
  emojiSelected(emoji) {
    this.args.status.emoji = emoji;
  }

  @action
  focus() {
    this.isFocused = true;
  }

  @action
  updateDescription(event) {
    this.args.status.description = event.target.value;
    this.args.status.emoji ||= "speech_balloon";
  }

  <template>
    <div class="user-status-picker-wrap">
      <div
        class={{concatClass
          "emoji-picker-anchor user-status-picker"
          (if this.isFocused "focused")
        }}
      >
        <EmojiPicker
          @emoji={{@status.emoji}}
          @didSelectEmoji={{this.emojiSelected}}
          @btnClass="btn-emoji"
          @modalForMobile={{false}}
          @context="user-status"
        />

        <input
          {{on "input" this.updateDescription}}
          {{on "focus" this.focus}}
          {{on "blur" this.blur}}
          {{autoFocus}}
          value={{@status.description}}
          type="text"
          placeholder={{i18n "user_status.what_are_you_doing"}}
          maxlength="100"
          class="user-status-description"
        />
      </div>
    </div>
  </template>
}
