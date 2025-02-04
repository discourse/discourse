import EmberObject from "@ember/object";
import { observes, on } from "@ember-decorators/object";
import { propertyNotEqual } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class ColorSchemeColor extends EmberObject {
  // Whether the current value is different than Discourse's default color scheme.
  @propertyNotEqual("hex", "default_hex") overridden;
  @on("init")
  startTrackingChanges() {
    this.set("originals", { hex: this.hex || "FFFFFF" });

    // force changed property to be recalculated
    this.notifyPropertyChange("hex");
  }

  // Whether value has changed since it was last saved.
  @discourseComputed("hex")
  changed(hex) {
    if (!this.originals) {
      return false;
    }
    if (hex !== this.originals.hex) {
      return true;
    }

    return false;
  }

  // Whether the saved value is different than Discourse's default color scheme.
  @discourseComputed("default_hex", "hex")
  savedIsOverriden(defaultHex) {
    return this.originals.hex !== defaultHex;
  }

  revert() {
    this.set("hex", this.default_hex);
  }

  undo() {
    if (this.originals) {
      this.set("hex", this.originals.hex);
    }
  }

  @discourseComputed("name")
  translatedName(name) {
    if (!this.is_advanced) {
      return i18n(`admin.customize.colors.${name}.name`);
    } else {
      return name;
    }
  }

  @discourseComputed("name")
  description(name) {
    if (!this.is_advanced) {
      return i18n(`admin.customize.colors.${name}.description`);
    } else {
      return "";
    }
  }

  /**
    brightness returns a number between 0 (darkest) to 255 (brightest).
    Undefined if hex is not a valid color.

    @property brightness
  **/
  @discourseComputed("hex")
  brightness(hex) {
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

  @discourseComputed("hex")
  valid(hex) {
    return hex.match(/^([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/) !== null;
  }
}
