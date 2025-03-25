import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import TextField from "discourse/components/text-field";

/**
  An input field for a color.

  @param hexValue is a reference to the color's hex value.
  @param brightnessValue is a number from 0 to 255 representing the brightness of the color. See ColorSchemeColor.
  @params valid is a boolean indicating if the input field is a valid color.
**/

@classNames("color-picker")
export default class ColorInput extends Component {
  onlyHex = true;
  styleSelection = true;

  @computed("onlyHex")
  get maxlength() {
    return this.onlyHex ? 6 : null;
  }

  @computed("hexValue")
  get normalizedHexValue() {
    return this.normalize(this.hexValue);
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
    />
    <input
      class="picker"
      type="color"
      value={{this.normalizedHexValue}}
      {{on "input" this.onPickerInput}}
      aria-labelledby={{this.ariaLabelledby}}
    />
  </template>
}
