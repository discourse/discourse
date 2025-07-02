import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { modifier } from "ember-modifier";
import { or } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class ImageAltTextInput extends Component {
  @tracked isExpanded = false;
  @tracked altText = this.args.data.alt || "";

  registerTextarea = modifier((element) => {
    this.textarea = element;
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

  <template>
    <div
      class={{concatClass
        "image-alt-text-input"
        (if this.isExpanded " --expanded")
      }}
    >
      {{#if this.isExpanded}}
        <textarea
          value={{this.altText}}
          placeholder={{i18n "composer.image_alt_text.title"}}
          class="image-alt-text-input__field"
          {{on "input" this.onInputChange}}
          {{on "blur" this.onBlur}}
          {{on "keydown" this.onKeyDown}}
          {{this.registerTextarea}}
        />
      {{else}}
        <div
          tabindex="0"
          class="image-alt-text-input__display"
          {{on "focus" this.expandInput}}
          {{on "click" this.expandInput}}
          {{on "touchstart" this.expandInput}}
        >
          {{or this.altText (i18n "composer.image_alt_text.title")}}
        </div>
      {{/if}}
    </div>
  </template>
}
