import { action, computed } from "@ember/object";
import Component from "@ember/component";
import { observes } from "discourse-common/utils/decorators";

/**
  An input field for a color.

  @param hexValue is a reference to the color's hex value.
  @param brightnessValue is a number from 0 to 255 representing the brightness of the color. See ColorSchemeColor.
  @params valid is a boolean indicating if the input field is a valid color.
**/
export default Component.extend({
  classNames: ["color-picker"],

  onlyHex: true,

  styleSelection: true,

  maxlength: computed("onlyHex", function () {
    return this.onlyHex ? 6 : null;
  }),

  normalizedHexValue: computed("hexValue", function () {
    return this.normalize(this.hexValue);
  }),

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
  },

  @action
  onHexInput(color) {
    if (this.attrs.onChangeColor) {
      this.attrs.onChangeColor(this.normalize(color || ""));
    }
  },

  @action
  onPickerInput(event) {
    this.set("hexValue", event.target.value.replace("#", ""));
  },

  @observes("hexValue", "brightnessValue", "valid")
  hexValueChanged() {
    const hex = this.hexValue;

    if (this.attrs.onChangeColor) {
      this.attrs.onChangeColor(this.normalize(hex));
    }

    if (this._valid()) {
      this.element.querySelector(".picker").value = this.normalize(hex);
    }
  },

  _valid(color = this.hexValue) {
    return /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(color);
  },
});
