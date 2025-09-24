/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import TextField from "discourse/components/text-field";

/**
  An input field for a color.

  @param {string} hexValue Reference to the color's hex value.
  @param {number} brightnessValue Number from 0 to 255 representing the brightness of the color. See ColorSchemeColor.
  @param {boolean} valid If the input field is a valid color.
  @param {string} [fallbackHexValue] Hex color string to use if hexValue is empty. Optional.
**/

@classNames("color-picker")
export default class ColorInput extends Component {
  onlyHex = true;
  styleSelection = true;

  @computed("onlyHex")
  get maxlength() {
    return this.onlyHex ? 6 : null;
  }

  @computed("hexValue", "fallbackHexValue")
  get hexValueWithFallback() {
    const { hexValue, fallbackHexValue } = this;
    return hexValue || (fallbackHexValue ? fallbackHexValue : hexValue);
  }

  @computed("hexValueWithFallback")
  get normalizedValue() {
    return this.normalize(this.hexValueWithFallback);
  }

  normalize(color) {
    if (this._valid(color)) {
      if (!color.startsWith("#")) {
        color = "#" + color;
      }
      if (color.length === 4) {
        color =
          "#" +
          color
            .slice(1)
            .split("")
            .map((hex) => hex + hex)
            .join("");
      }
    }
    return color;
  }

  @action
  onHexInput(event) {
    if (this.onChangeColor) {
      this.onChangeColor(this.normalize(event.target.value || ""));
    }
  }

  @action
  onPickerInput(event) {
    this.set("hexValue", event.target.value.replace("#", ""));
  }

  @action
  handlePaste(event) {
    event.preventDefault();
    const colorCode = event.clipboardData.getData("text/plain") ?? "";

    this.set("hexValue", colorCode.replace(/^#/, ""));
  }

  @action
  handleBlur() {
    this.onBlur?.(this.normalize(this.hexValue));
  }

  @observes("hexValue", "brightnessValue", "valid")
  hexValueChanged() {
    const hex = this.hexValue;

    if (this.onChangeColor) {
      this.onChangeColor(this.normalize(hex));
    }

    if (this._valid()) {
      this.element.querySelector(".picker").value = this.normalize(hex);
    }
  }

  _valid(color = this.hexValue) {
    return /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(color);
  }

  <template>
    {{#if this.onlyHex}}<span class="add-on">#</span>{{/if}}<TextField
      @value={{this.hexValue}}
      @maxlength={{this.maxlength}}
      @input={{this.onHexInput}}
      class="hex-input"
      aria-labelledby={{this.ariaLabelledby}}
      {{on "blur" this.handleBlur}}
      {{on "paste" this.handlePaste}}
    />
    <input
      class="picker"
      type="color"
      value={{this.normalizedValue}}
      title={{this.normalizedValue}}
      {{on "input" this.onPickerInput}}
      aria-labelledby={{this.ariaLabelledby}}
    />
  </template>
}
