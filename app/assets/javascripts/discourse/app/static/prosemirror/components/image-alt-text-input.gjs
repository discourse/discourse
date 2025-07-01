import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { modifier } from "ember-modifier";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class ImageAltTextInput extends Component {
  @tracked isExpanded = false;
  @tracked altText = this.args.data.alt || "";

  registerTextarea = modifier((element) => {
    this.textarea = element;

    // Without this, the textarea will not be focused when the user taps on it
    // on mobile
    const handleTouchStart = () => this.textarea.focus();
    this.textarea.addEventListener("touchstart", handleTouchStart);

    return () => {
      this.textarea.removeEventListener("touchstart", handleTouchStart);
    };
  });

  @action
  expandInput() {
    this.isExpanded = true;

    next(() => this.textarea.select());
  }

  @action
  onInputChange(event) {
    this.altText = event.target.value;
  }

  @action
  onBlur() {
    this.isExpanded = false;
    this.args.data.onSave?.(this.altText.trim());
  }

  @action
  resetAltText() {
    this.altText = "";
    this.args.data.onClose?.();
  }

  @action
  onKeyDown(event) {
    event.stopPropagation();
    if (event.key === "Enter") {
      event.preventDefault();
      this.onBlur();
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.args.data.onClose?.();
    }
  }

  @action
  onKeyPress(event) {
    event.stopPropagation();
  }

  <template>
    <div
      class={{concatClass
        "image-alt-text-input"
        (if this.isExpanded " --expanded")
      }}
    >
      <textarea
        value={{if this.isExpanded this.altText " "}}
        placeholder={{i18n "composer.image_alt_text.title"}}
        class="image-alt-text-input__field"
        {{on "input" this.onInputChange}}
        {{on "focus" this.expandInput}}
        {{on "blur" this.onBlur}}
        {{on "keydown" this.onKeyDown}}
        {{on "keypress" this.onKeyPress}}
        {{this.registerTextarea}}
      />
      {{#if this.isExpanded}}
        <DButton
          @icon="xmark"
          @action={{this.resetAltText}}
          @preventFocus={{true}}
          class="image-alt-text-input__reset"
          title={{i18n "composer.image_toolbar.alt_text_reset"}}
        />
      {{else}}
        <span class="image-alt-text-input__display">
          {{or this.altText (i18n "composer.image_alt_text.title")}}
        </span>
      {{/if}}
    </div>
  </template>
}
