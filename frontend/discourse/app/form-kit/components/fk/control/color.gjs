import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import {
  isValidHex,
  normalizeHex,
  resolveColor,
} from "discourse/lib/color-transformations";
import { i18n } from "discourse-i18n";

function isColorUsed(usedColors, color) {
  const normalizedColor = color.toUpperCase();
  return usedColors?.some((c) => c.toUpperCase() === normalizedColor);
}

function colorStyle(color) {
  return htmlSafe(`background-color: #${color};`);
}

function colorLabel(usedColors, color) {
  const usedText = isColorUsed(usedColors, color)
    ? ` ${i18n("category.color_used")}`
    : "";
  return `#${color}${usedText}`;
}

export default class FKControlColor extends Component {
  static controlType = "color";

  get showPrefix() {
    return !this.args.allowNamedColors;
  }

  get maxLength() {
    return this.args.allowNamedColors ? null : 6;
  }

  get normalizedValueForPicker() {
    const value = this.args.field.value;
    if (!value) {
      return "#000000";
    }

    if (isValidHex(value)) {
      return `#${normalizeHex(value)}`;
    }

    if (this.args.allowNamedColors) {
      return resolveColor(value) ?? "#000000";
    }

    return "#000000";
  }

  @action
  handleTextInput(event) {
    this.args.field.set(event.target.value);
  }

  @action
  handlePickerInput(event) {
    this.args.field.set(event.target.value.replace(/^#/, ""));
  }

  @action
  handlePaste(event) {
    event.preventDefault();
    const colorCode = event.clipboardData.getData("text/plain") ?? "";
    this.args.field.set(colorCode.replace(/^#/, ""));
  }

  @action
  selectColor(color) {
    this.args.field.set(color);
  }

  <template>
    <div class="form-kit__control-color">
      <div class="form-kit__control-color-input">
        {{#if this.showPrefix}}
          <span class="form-kit__control-color-input-prefix">#</span>
        {{/if}}
        <input
          type="text"
          value={{@field.value}}
          maxlength={{this.maxLength}}
          class="form-kit__control-color-input-hex"
          disabled={{@field.disabled}}
          {{on "input" this.handleTextInput}}
          {{on "paste" this.handlePaste}}
          ...attributes
        />
        <input
          type="color"
          value={{this.normalizedValueForPicker}}
          class="form-kit__control-color-input-picker"
          disabled={{@field.disabled}}
          {{on "input" this.handlePickerInput}}
        />
      </div>

      {{#if @colors}}
        <div class="form-kit__control-color-swatches" role="group">
          {{#each @colors as |color|}}
            <button
              type="button"
              style={{colorStyle color}}
              class={{concatClass
                "form-kit__control-color-swatch"
                (if (isColorUsed @usedColors color) "is-used")
              }}
              title={{if
                (isColorUsed @usedColors color)
                (i18n "category.already_used")
              }}
              aria-label={{colorLabel @usedColors color}}
              data-color={{color}}
              disabled={{@field.disabled}}
              {{on "click" (fn this.selectColor color)}}
            >
              {{#if (isColorUsed @usedColors color)}}
                {{icon "check"}}
              {{/if}}
            </button>
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
