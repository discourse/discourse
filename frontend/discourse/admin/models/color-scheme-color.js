import { tracked } from "@glimmer/tracking";
import EmberObject, { computed } from "@ember/object";
import { observes, on } from "@ember-decorators/object";
import { propertyNotEqual } from "discourse/lib/computed";
import { i18n } from "discourse-i18n";

export default class ColorSchemeColor extends EmberObject {
  @tracked hex;

  @tracked originalHex;

  // Whether the current value is different than Discourse's default color scheme.
  @propertyNotEqual("hex", "default_hex") overridden;

  init(object) {
    super.init(...arguments);
    this.originalHex = object.hex;
  }

  discardColorChange() {
    this.hex = this.originalHex;
  }

  @on("init")
  startTrackingChanges() {
    this.set("originals", {
      hex: this.hex || "FFFFFF",
    });

    // force changed property to be recalculated
    this.notifyPropertyChange("hex");
  }

  // Whether value has changed since it was last saved.
  @computed("hex")
  get changed() {
    if (!this.originals) {
      return false;
    }
    if (this.hex !== this.originals.hex) {
      return true;
    }
    return false;
  }

  // Whether the saved value is different than Discourse's default color scheme.
  @computed("default_hex", "hex")
  get savedIsOverriden() {
    if (!this.default_hex) {
      return false;
    }
    return this.originals.hex !== this.default_hex;
  }

  revert() {
    this.set("hex", this.default_hex);
  }

  undo() {
    if (this.originals) {
      this.set("hex", this.originals.hex);
    }
  }

  @computed("name")
  get translatedName() {
    return i18n(`admin.customize.colors.${this.name}.name`, {
      defaultValue: this.name,
    });
  }

  @computed("name")
  get description() {
    return i18n(`admin.customize.colors.${this.name}.description`, {
      defaultValue: "",
    });
  }

  /**
    brightness returns a number between 0 (darkest) to 255 (brightest).
    Undefined if hex is not a valid color.

    @property brightness
  **/
  @computed("hex")
  get brightness() {
    let hex = this.hex;
    if (hex.length === 6 || hex.length === 3) {
      if (hex.length === 3) {
        hex =
          hex.slice(0, 1) +
          hex.slice(0, 1) +
          hex.slice(1, 2) +
          hex.slice(1, 2) +
          hex.slice(2, 3) +
          hex.slice(2, 3);
      }
      return Math.round(
        (parseInt(hex.slice(0, 2), 16) * 299 +
          parseInt(hex.slice(2, 4), 16) * 587 +
          parseInt(hex.slice(4, 6), 16) * 114) /
          1000
      );
    }
  }

  @observes("hex")
  hexValueChanged() {
    if (this.hex) {
      this.set("hex", this.hex.toString().replace(/[^0-9a-fA-F]/g, ""));
    }
  }

  @computed("hex")
  get valid() {
    return this.hex.match(/^([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/) !== null;
  }
}
