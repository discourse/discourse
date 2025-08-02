import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export const LIGHT = "light";
export const DARK = "dark";

function isColorOverriden(color, darkModeActive) {
  if (darkModeActive) {
    return color.default_dark_hex && color.default_dark_hex !== color.dark_hex;
  } else {
    return color.default_hex && color.default_hex !== color.hex;
  }
}

const NavTab = <template>
  <li>
    <a
      class={{concatClass "" (if @active "active")}}
      tabindex="0"
      {{on "click" @action}}
      {{on "keydown" @action}}
      ...attributes
    >
      {{icon @icon}}
      <span>{{@label}}</span>
    </a>
  </li>
</template>;

const Picker = class extends Component {
  @service toasts;

  @tracked invalid = false;

  @action
  onInput(event) {
    const color = event.target.value.replace("#", "");
    if (this.args.showDark) {
      this.args.onDarkChange(color);
    } else {
      this.args.onLightChange(color);
    }
  }

  @action
  onChange(event) {
    const color = event.target.value.replace("#", "");
    if (this.args.showDark) {
      this.args.onDarkChange(color);
    } else {
      this.args.onLightChange(color);
    }
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
    if (this.args.showDark) {
      this.args.onDarkChange(color);
    } else {
      this.args.onLightChange(color);
    }
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
    const content = (event.clipboardData || window.clipboardData).getData(
      "text"
    );

    if (!this.isValidHex(content)) {
      event.preventDefault();
      this.toasts.error({
        data: {
          message: i18n(
            "admin.config_areas.color_palettes.invalid_color_length"
          ),
        },
      });
      return;
    }
  }

  get displayedColor() {
    let color;
    if (this.args.showDark) {
      color = this.args.color.dark_hex;
    } else {
      color = this.args.color.hex;
    }

    return this.ensureSixDigitsHex(color);
  }

  get activeValue() {
    let color;
    if (this.args.showDark) {
      color = this.args.color.dark_hex;
    } else {
      color = this.args.color.hex;
    }

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
        disabled={{@system}}
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
          disabled={{@system}}
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
  @tracked selectedMode;
  editorElement;

  get currentMode() {
    return this.selectedMode ?? this.args.initialMode ?? LIGHT;
  }

  get lightModeActive() {
    return this.currentMode === LIGHT;
  }

  get darkModeActive() {
    return this.currentMode === DARK;
  }

  @action
  changeMode(newMode, event) {
    if (
      event.type === "click" ||
      (event.type === "keydown" && event.keyCode === 13)
    ) {
      if (this.args.onTabSwitch) {
        this.args.onTabSwitch(newMode);
      } else {
        this.selectedMode = newMode;
      }
    }
  }

  @action
  revert(color) {
    if (this.darkModeActive) {
      this.args.onDarkColorChange(color, color.default_dark_hex);
    } else {
      this.args.onLightColorChange(color, color.default_hex);
    }
  }

  @action
  editorInserted(element) {
    this.editorElement = element;
  }

  <template>
    <div class="color-palette-editor" {{didInsert this.editorInserted}}>
      <div class="nav-pills color-palette-editor__nav-pills">
        <NavTab
          @active={{this.lightModeActive}}
          @action={{fn this.changeMode LIGHT}}
          @icon="sun"
          @label={{i18n "admin.customize.colors.editor.light"}}
          class="light-tab"
        />
        <NavTab
          @active={{this.darkModeActive}}
          @action={{fn this.changeMode DARK}}
          @icon="moon"
          @label={{i18n "admin.customize.colors.editor.dark"}}
          class="dark-tab"
        />
      </div>
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
                @showDark={{this.darkModeActive}}
                @onLightChange={{fn @onLightColorChange color}}
                @onDarkChange={{fn @onDarkColorChange color}}
                @system={{@system}}
              />
              {{#unless @hideRevertButton}}
                <DButton
                  class={{concatClass
                    "btn-flat"
                    "color-palette-editor__revert"
                    (unless
                      (isColorOverriden color this.darkModeActive) "--hidden"
                    )
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
