import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { replacements } from "pretty-text/emoji/data";
import DButton from "discourse/components/d-button";
import EmojiPicker from "discourse/components/emoji-picker";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

let _nameToUnicode;
function emojiToUnicode(name) {
  if (!_nameToUnicode) {
    _nameToUnicode = {};
    for (const [unicode, emojiName] of Object.entries(replacements)) {
      _nameToUnicode[emojiName] ??= unicode;
    }
  }
  return _nameToUnicode[name] ?? `:${name}:`;
}

export default class BoostInput extends Component {
  @tracked value = "";

  get canSubmit() {
    return this.value.trim().length > 0 && this.value.length <= 16;
  }

  get placeholder() {
    return i18n("discourse_boosts.boost_input_placeholder", {
      username: this.args.post.username,
    });
  }

  @action
  updateValue(event) {
    const val = event.target.value;
    if (val.length <= 16) {
      this.value = val;
    }
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter" && this.canSubmit) {
      event.preventDefault();
      this.args.onSubmit(this.value.trim());
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.args.onClose();
    }
  }

  @action
  submit() {
    if (this.canSubmit) {
      this.args.onSubmit(this.value.trim());
    }
  }

  @action
  didSelectEmoji(emoji) {
    const unicode = emojiToUnicode(emoji);
    const newValue = this.value + unicode;
    if (newValue.length <= 16) {
      this.value = newValue;
    }
  }

  <template>
    <div class="discourse-boosts__input-container">
      {{boundAvatarTemplate @post.avatar_template "small"}}
      <input
        type="text"
        class="discourse-boosts__input"
        maxlength="16"
        placeholder={{this.placeholder}}
        value={{this.value}}
        {{on "input" this.updateValue}}
        {{on "keydown" this.handleKeydown}}
      />
      <EmojiPicker
        @didSelectEmoji={{this.didSelectEmoji}}
        @btnClass="btn-transparent discourse-boosts__emoji-btn"
        @context="boost"
        @modalForMobile={{false}}
      />
      <DButton
        @action={{this.submit}}
        @icon="check"
        @disabled={{not this.canSubmit}}
        class="btn-default --success btn-icon-only btn-default discourse-boosts__submit"
      />
      <DButton
        @action={{@onClose}}
        @icon="xmark"
        class="btn-default --danger btn-icon-only discourse-boosts__cancel"
      />
    </div>
  </template>
}
