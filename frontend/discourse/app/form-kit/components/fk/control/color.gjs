import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import {
  isValidHex,
  normalizeHex,
  resolveColor,
} from "discourse/lib/color-transformations";
import { and } from "discourse/truth-helpers";
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

function calculateLuminance(hex) {
  if (!hex || hex.length < 3) {
    return 1;
  }

  let normalized = hex.toUpperCase();

  if (normalized.length === 3) {
    normalized =
      normalized[0] +
      normalized[0] +
      normalized[1] +
      normalized[1] +
      normalized[2] +
      normalized[2];
  }

  const r = parseInt(normalized.slice(0, 2), 16);
  const g = parseInt(normalized.slice(2, 4), 16);
  const b = parseInt(normalized.slice(4, 6), 16);

  return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
}

function colorLuminanceClass(color) {
  return calculateLuminance(color) > 0.5 ? "--is-light" : "--is-dark";
}

export default class FKControlColor extends Component {
  static controlType = "color";

  get showPrefix() {
    return !this.args.allowNamedColors;
  }

  get maxLength() {
    return this.args.allowNamedColors ? null : 6;
  }

  get sortedColors() {
    if (!this.args.usedColors) {
      return this.args.colors;
    }

    return this.args.colors.sort((a) =>
      isColorUsed(this.args.usedColors, a) ? 1 : -1
    );
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

  get pickerIconClass() {
    const value = this.args.field.value;
    if (!value || !isValidHex(value)) {
      return "--is-light";
    }

    const hex = normalizeHex(value);
    return calculateLuminance(hex) > 0.5 ? "--is-light" : "--is-dark";
  }

  @action
  handleTextInput(event) {
    this.args.field.set(event.target.value);
  }

  @action
  handleBlur() {
    if (!this.args.field.value && this.args.fallbackValue) {
      this.args.field.set(this.args.fallbackValue);
    }
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
  selectColor(color, closeMenu) {
    this.args.field.set(color);
    if (typeof closeMenu === "function") {
      closeMenu();
    }
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
          {{on "blur" this.handleBlur}}
          {{on "paste" this.handlePaste}}
          ...attributes
        />
        <span
          class={{concatClass
            "form-kit__control-color-picker-wrapper"
            this.pickerIconClass
          }}
        >
          <input
            type="color"
            value={{this.normalizedValueForPicker}}
            class="form-kit__control-color-input-picker"
            disabled={{@field.disabled}}
            {{on "input" this.handlePickerInput}}
          />
          {{icon "eye-dropper"}}
        </span>
        {{#if (and @colors @collapseSwatches)}}
          <DMenu
            @identifier="color-swatches-menu"
            @icon="palette"
            @title={{@collapseSwatchesLabel}}
            @modalForMobile={{true}}
            class="btn-default form-kit__control-color-swatches-btn"
          >
            <:content as |args|>
              <div class="form-kit__control-color-swatches" role="group">
                {{#each this.sortedColors as |color|}}
                  <button
                    type="button"
                    style={{colorStyle color}}
                    class={{concatClass
                      "form-kit__control-color-swatch"
                      (if (isColorUsed @usedColors color) "is-used")
                      (colorLuminanceClass color)
                    }}
                    title={{if
                      (isColorUsed @usedColors color)
                      (i18n "category.already_used")
                    }}
                    aria-label={{colorLabel @usedColors color}}
                    data-color={{color}}
                    {{on "click" (fn this.selectColor color args.close)}}
                  >
                    {{#if (isColorUsed @usedColors color)}}
                      {{icon "check"}}
                    {{/if}}
                  </button>
                {{/each}}
              </div>
            </:content>
          </DMenu>
        {{/if}}
      </div>

      {{#if @colors}}
        {{#unless @collapseSwatches}}
          <div class="form-kit__control-color-swatches" role="group">
            {{#each this.sortedColors as |color|}}
              <button
                type="button"
                style={{colorStyle color}}
                class={{concatClass
                  "form-kit__control-color-swatch"
                  (if (isColorUsed @usedColors color) "is-used")
                  (colorLuminanceClass color)
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
        {{/unless}}
      {{/if}}
    </div>
  </template>
}
