import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next } from "@ember/runloop";
import { or } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class ImageAltTextInput extends Component {
  @tracked isExpanded = false;

  @tracked initialAltText = this.args.data.alt || "";
  @tracked transientAltText = this.initialAltText;

  @action
  expandInput() {
    this.isExpanded = true;

    next(() => this.textarea.select());
  }

  @action
  setupTextarea(element) {
    this.textarea = element;
  }

  @action
  onInputChange(event) {
    this.transientAltText = event.target.value;
  }

  @action
  onBlur(event) {
    // helps avoid a shift of the composer window on mobile
    const forceFocus = event.relatedTarget === this.args.data.view.dom;

    this.isExpanded = false;
    this.initialAltText = this.transientAltText;
    this.args.data.onSave?.(this.transientAltText.trim(), forceFocus);
  }

  @action
  onKeyDown(event) {
    event.stopPropagation();
    if (event.key === "Enter") {
      event.preventDefault();
      this.args.data.onClose?.();
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.transientAltText = this.initialAltText;
      this.args.data.onClose?.();
    }
  }

  <template>
    <div
      class={{concatClass
        "image-alt-text-input"
        (if this.isExpanded "--expanded")
      }}
    >
      {{#if this.isExpanded}}
        <textarea
          value={{this.transientAltText}}
          placeholder={{i18n "composer.image_alt_text.title"}}
          class="image-alt-text-input__field"
          {{on "input" this.onInputChange}}
          {{on "blur" this.onBlur}}
          {{on "keydown" this.onKeyDown}}
          {{didInsert this.setupTextarea}}
        />
      {{else}}
        <div
          tabindex="0"
          class="image-alt-text-input__display"
          {{on "focus" this.expandInput}}
          {{on "click" this.expandInput}}
        >
          {{or this.transientAltText (i18n "composer.image_alt_text.title")}}
        </div>
      {{/if}}
    </div>
  </template>
}
