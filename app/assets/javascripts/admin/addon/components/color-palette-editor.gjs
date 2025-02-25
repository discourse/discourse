import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const LIGHT = "light";
const DARK = "dark";

class Color {
  @tracked lightValue;
  @tracked darkValue;

  constructor({ name, lightValue, darkValue }) {
    this.name = name;
    this.lightValue = lightValue;
    this.darkValue = darkValue;
  }

  get displayName() {
    return this.name.replaceAll("_", " ");
  }

  get description() {
    return i18n(`admin.customize.colors.${this.name}.description`);
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
      {{dIcon @icon}}
      <span>{{@label}}</span>
    </a>
  </li>
</template>;

const Picker = class extends Component {
  @action
  onInput(event) {
    const color = event.target.value.replace("#", "");
    if (this.args.showDark) {
      this.args.color.darkValue = color;
    } else {
      this.args.color.lightValue = color;
    }
  }

  @action
  onChange(event) {
    const color = event.target.value.replace("#", "");
    if (this.args.showDark) {
      this.args.onDarkChange(color);
      this.args.color.darkValue = color;
    } else {
      this.args.onLightChange(color);
      this.args.color.lightValue = color;
    }
  }

  get displayedColor() {
    if (this.args.showDark) {
      return this.args.color.darkValue;
    } else {
      return this.args.color.lightValue;
    }
  }

  get activeValue() {
    let color;
    if (this.args.showDark) {
      color = this.args.color.darkValue;
    } else {
      color = this.args.color.lightValue;
    }

    if (color) {
      return `#${color}`;
    }
  }

  <template>
    <input
      class="color-palette-editor__input"
      type="color"
      value={{this.activeValue}}
      {{on "input" this.onInput}}
      {{on "change" this.onChange}}
    />
    {{dIcon "hashtag"}}
    <span
      class="color-palette-editor__color-code"
    >{{this.displayedColor}}</span>
  </template>
};

export default class ColorPaletteEditor extends Component {
  @tracked selectedMode;

  get currentMode() {
    return this.selectedMode ?? this.args.initialMode ?? LIGHT;
  }

  get lightModeActive() {
    return this.currentMode === LIGHT;
  }

  get darkModeActive() {
    return this.currentMode === DARK;
  }

  get colors() {
    return this.args.colors.map((color) => {
      return new Color({
        name: color.name,
        lightValue: color.hex,
        darkValue: color.dark_hex,
      });
    });
  }

  @action
  changeMode(newMode, event) {
    if (
      event.type === "click" ||
      (event.type === "keydown" && event.keyCode === 13)
    ) {
      this.selectedMode = newMode;
    }
  }

  <template>
    <div class="color-palette-editor">
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
        {{#each this.colors as |color|}}
          <div
            data-color-name={{color.name}}
            class="color-palette-editor__colors-item"
          >
            <div class="color-palette-editor__color-info">
              <div class="color-palette-editor__color-description">
                {{color.description}}
              </div>
              <div class="color-palette-editor__color-name">
                {{color.displayName}}
              </div>
            </div>
            <div class="color-palette-editor__picker">
              <Picker
                @color={{color}}
                @showDark={{this.darkModeActive}}
                @onLightChange={{fn @onLightColorChange color.name}}
                @onDarkChange={{fn @onDarkColorChange color.name}}
              />
            </div>
          </div>
        {{/each}}
      </div>
    </div>
  </template>
}
