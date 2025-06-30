import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class ImageAltTextInput extends Component {
  @tracked isExpanded = false;
  @tracked altText = this.args.data.alt || "";

  @action
  expandInput() {
    this.isExpanded = true;
  }

  @action
  onInputChange(event) {
    this.altText = event.target.value;
  }

  @action
  onBlur() {
    this.isExpanded = false;
    this.positionCaretAtStart();
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

  @action
  positionCaretAtStart() {
    const textarea = document.querySelector(".image-alt-text-input__field");
    if (textarea) {
      textarea.setSelectionRange(0, 0);
      textarea.scrollTop = 0;
    }
  }

  <template>
    <div
      class={{concatClass
        "image-alt-text-input"
        (if this.isExpanded " --expanded")
      }}
    >
      <textarea
        value={{this.altText}}
        placeholder={{i18n "composer.image_alt_text.title"}}
        class="image-alt-text-input__field"
        {{on "input" this.onInputChange}}
        {{on "focus" this.expandInput}}
        {{on "blur" this.onBlur}}
        {{on "keydown" this.onKeyDown}}
        {{on "keypress" this.onKeyPress}}
      />
      {{#if this.isExpanded}}
        <DButton
          @icon="xmark"
          @action={{this.resetAltText}}
          @preventFocus={{true}}
          class="image-alt-text-input__reset"
          title={{i18n "composer.image_alt_text.reset"}}
        />
      {{/if}}
    </div>
  </template>
}
