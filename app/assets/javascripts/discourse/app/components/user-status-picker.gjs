import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import EmojiPicker from "discourse/components/emoji-picker";
import concatClass from "discourse/helpers/concat-class";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";

export default class UserStatusPicker extends Component {
  @tracked isFocused = false;
  @tracked emojiPickerIsActive = false;

  get emojiHtml() {
    return emojiUnescape(escapeExpression(`:${this.args.status.emoji}:`));
  }

  focusEmojiButton() {
    document.querySelector(".user-status-picker .btn-emoji")?.focus();
  }

  @action
  blur() {
    this.isFocused = false;
  }

  @action
  emojiSelected(emoji) {
    this.args.status.emoji = emoji;
    this.emojiPickerIsActive = false;

    scheduleOnce("afterRender", this, this.focusEmojiButton);
  }

  @action
  focus() {
    this.isFocused = true;
  }

  @action
  onEmojiPickerOutsideClick() {
    this.emojiPickerIsActive = false;
  }

  @action
  updateDescription(event) {
    this.args.status.description = event.target.value;
    this.args.status.emoji ||= "speech_balloon";
  }

  @action
  toggleEmojiPicker() {
    this.emojiPickerIsActive = !this.emojiPickerIsActive;
  }

  <template>
    <div class="user-status-picker-wrap">
      <div
        class={{concatClass
          "emoji-picker-anchor user-status-picker"
          (if this.isFocused "focused")
        }}
      >
        <DButton
          {{on "focus" this.focus}}
          {{on "blur" this.blur}}
          @action={{this.toggleEmojiPicker}}
          @icon={{unless @status.emoji "discourse-emojis"}}
          @translatedLabel={{if @status.emoji (htmlSafe this.emojiHtml)}}
          class="btn-emoji btn-transparent"
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

    <EmojiPicker
      @isActive={{this.emojiPickerIsActive}}
      @emojiSelected={{this.emojiSelected}}
      @onEmojiPickerClose={{this.onEmojiPickerOutsideClick}}
      @placement="bottom"
    />
  </template>
}
