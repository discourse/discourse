import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const LIGHT = "light";
const DARK = "dark";

const NavTab = <template>
  <li>
    <a
      class={{concatClass "" (if @active "active")}}
      tabindex="0"
      {{on "click" (fn @action @mode)}}
      {{on "keydown" (fn @action @mode)}}
    >
      {{dIcon @icon}}
      <span>{{@label}}</span>
    </a>
  </li>
</template>;

const Picker = class extends Component {
  @tracked displayedColor = this.args.color.value;

  @action
  onInput(event) {
    this.displayedColor = event.target.value.replace("#", "");
  }

  @action
  onChange(event) {
    const color = event.target.value.replace("#", "");
    this.displayedColor = color;
    this.args.onChange(color);
  }

  <template>
    <input
      class="color-palette-editor__input"
      type="color"
      value={{concat "#" @color.value}}
      {{on "input" this.onInput}}
      {{on "change" this.onChange}}
    />
    {{dIcon "hashtag"}}
    <span
      class="color-palette-editor__color-code"
    >{{this.displayedColor}}</span>
  </template>
};

class Color {
  @tracked displayValue = this.value;

  constructor({ name, value, description }) {
    this.name = name;
    this.value = value;
    this.description = description;
    this.displayName = name.replaceAll("_", " ");
  }
}

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
    const dark = this.darkModeActive;
    return this.args.colors.map((color) => {
      return new Color({
        name: color.name,
        value: dark ? color.dark_hex || color.hex : color.hex,
        description: i18n(`admin.customize.colors.${color.name}.description`),
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

  @action
  onColorChange(/* colorName, newValue */) {
    // console.log(colorName, newValue);
  }

  <template>
    <div class="color-palette-editor">
      <div class="nav-pills color-palette-editor__nav-pills">
        <NavTab
          @active={{this.lightModeActive}}
          @action={{this.changeMode}}
          @mode={{LIGHT}}
          @icon="sun"
          @label="Light"
        />
        <NavTab
          @active={{this.darkModeActive}}
          @action={{this.changeMode}}
          @mode={{DARK}}
          @icon="moon"
          @label="Dark"
        />
      </div>
      <div class="color-palette-editor__colors-list">
        {{#each this.colors as |color|}}
          <div class="color-palette-editor__colors-item">
            <div class="color-palette-editor__color-description">
              {{color.description}}
              <div class="color-palette-editor__color-name">
                {{color.displayName}}
              </div>
            </div>
            <div class="color-palette-editor__picker">
              <Picker
                @color={{color}}
                @onChange={{fn this.onColorChange color.name}}
              />
            </div>
          </div>
        {{/each}}
      </div>
    </div>
  </template>
}
