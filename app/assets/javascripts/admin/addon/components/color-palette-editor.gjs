import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

function isColorOverriden(color) {
  return color.default_hex && color.default_hex !== color.hex;
}

const Picker = class extends Component {
  @service toasts;

  @tracked invalid = false;

  @action
  onInput(event) {
    const color = event.target.value.replace("#", "");
    this.args.onChange(color);
  }

  @action
  onChange(event) {
    const color = event.target.value.replace("#", "");
    this.args.onChange(color);
  }

  @action
  onTextChange(event) {
    let color = event.target.value;

    if (!this.isValidHex(color)) {
      event.preventDefault();
      this.invalid = true;
      this.toasts.error({
        data: {
          message: i18n(
            "admin.config_areas.color_palettes.invalid_color_length"
          ),
        },
      });
      return;
    }
    this.invalid = false;

    color = this.ensureSixDigitsHex(color);
    this.args.onChange(color);
  }

  @action
  onTextKeypress(event) {
    const currentValue = event.target.value;

    if (event.keyCode === 13) {
      event.preventDefault();

      if (currentValue.length !== 6 && currentValue.length !== 3) {
        this.invalid = true;
        this.toasts.error({
          data: {
            message: i18n(
              "admin.config_areas.color_palettes.invalid_color_length"
            ),
          },
        });
        return;
      }
      this.invalid = false;

      const nextPosition = this.args.position + 1;
      if (nextPosition < this.args.totalColors) {
        this.args.editorElement
          .querySelector(
            `.color-palette-editor__text-input[data-position="${nextPosition}"]`
          )
          .focus();
      }
      return;
    }

    const color = currentValue + event.key;

    if (color && !color.match(/^[0-9A-Fa-f]+$/)) {
      event.preventDefault();
      this.invalid = true;
      this.toasts.error({
        data: {
          message: i18n(
            "admin.config_areas.color_palettes.illegal_character_in_color"
          ),
        },
      });
    } else {
      this.invalid = false;
    }
  }

  @action
  onTextPaste(event) {
    event.preventDefault();

    const content = (event.clipboardData || window.clipboardData)
      .getData("text")
      .trim()
      .replace(/^#/, "");

    if (this.isValidHex(content)) {
      this.args.onChange(this.ensureSixDigitsHex(content));
    } else {
      this.toasts.error({
        data: {
          message: i18n(
            "admin.config_areas.color_palettes.invalid_color_length"
          ),
        },
      });
    }
  }

  get displayedColor() {
    const color = this.args.color.hex;
    return this.ensureSixDigitsHex(color);
  }

  get activeValue() {
    const color = this.args.color.hex;

    if (color) {
      return `#${this.ensureSixDigitsHex(color)}`;
    }
  }

  get disabledEditForSystemDescription() {
    if (!this.args.system) {
      return null;
    }
    return i18n("admin.config_areas.color_palettes.blocked_edit_for_system");
  }

  ensureSixDigitsHex(hex) {
    if (hex.length === 3) {
      return hex
        .split("")
        .map((digit) => `${digit}${digit}`)
        .join("");
    }
    return hex;
  }

  isValidHex(hex) {
    return !!hex?.match(/^([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$/);
  }

  <template>
    <div
      class={{concatClass
        "color-palette-editor__picker"
        "form-kit__control-input"
        (if this.invalid "--invalid")
      }}
    >
      <input
        class="color-palette-editor__input"
        data-position={{@position}}
        type="color"
        value={{this.activeValue}}
        disabled={{or @system @disabled}}
        title={{this.disabledEditForSystemDescription}}
        {{on "input" this.onInput}}
        {{on "change" this.onChange}}
      />
      <div class="color-palette-editor__input-wrapper">
        {{icon "hashtag" class="color-palette-editor__icon"}}
        <input
          class="color-palette-editor__text-input"
          data-position={{@position}}
          type="text"
          maxlength="6"
          disabled={{or @system @disabled}}
          title={{this.disabledEditForSystemDescription}}
          value={{this.displayedColor}}
          {{on "keypress" this.onTextKeypress}}
          {{on "change" this.onTextChange}}
          {{on "paste" this.onTextPaste}}
        />
      </div>
    </div>
  </template>
};

export default class ColorPaletteEditor extends Component {
  editorElement;

  @action
  revert(color) {
    this.args.onColorChange(color, color.default_hex);
  }

  @action
  editorInserted(element) {
    this.editorElement = element;
  }

  <template>
    <div class="color-palette-editor" {{didInsert this.editorInserted}}>
      <div class="color-palette-editor__colors-list">
        {{#each @colors as |color index|}}
          <div
            data-color-name={{color.name}}
            class="color-palette-editor__colors-item"
          >
            <div class="color-palette-editor__color-info">
              <div
                class="color-palette-editor__color-description form-kit__container-title"
              >
                {{#if color.description}}
                  {{color.description}}
                {{else}}
                  {{color.translatedName}}
                {{/if}}
              </div>
              {{#if color.description}}
                <div class="color-palette-editor__color-name">
                  {{color.translatedName}}
                </div>
              {{/if}}
            </div>
            <div class="color-palette-editor__color-controls">
              <Picker
                @color={{color}}
                @position={{index}}
                @totalColors={{@colors.length}}
                @editorElement={{this.editorElement}}
                @onChange={{fn @onColorChange color}}
                @system={{@system}}
                @disabled={{@disabled}}
              />
              {{#unless @disabled}}
                <DButton
                  class={{concatClass
                    "btn-flat"
                    "color-palette-editor__revert"
                    (unless (isColorOverriden color) "--hidden")
                  }}
                  @icon="arrow-rotate-left"
                  @action={{fn this.revert color}}
                />
              {{/unless}}
            </div>
          </div>
        {{/each}}
      </div>
    </div>
  </template>
}
