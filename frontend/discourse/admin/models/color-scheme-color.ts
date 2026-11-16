/* eslint-disable ember/no-observers */
import { tracked } from "@glimmer/tracking";
import EmberObject, { computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { observes, on } from "@ember-decorators/object";
import { isValidHex, normalizeHex } from "discourse/lib/color-transformations";
import { deepEqual } from "discourse/lib/object";
import { i18n } from "discourse-i18n";

/** A palette color; custom colors without a base default send a null `default_hex`. */
export interface ColorSchemeColorFields {
  name: string;
  is_advanced?: boolean;
  originals: { hex: string };
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface ColorSchemeColor extends ColorSchemeColorFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class ColorSchemeColor extends EmberObject {
  /** Revert copies `default_hex`, so this can be null or absent too. */
  @tracked hex: string | null | undefined;

  @tracked originalHex: string | null | undefined;
  @tracked default_hex: string | null | undefined;

  // Whether the current value is different than Discourse's default color scheme.

  init(object: { hex?: string | null }) {
    // eslint-disable-next-line prefer-rest-params
    super.init(...(arguments as unknown as [object]));
    this.originalHex = object.hex;
  }

  @dependentKeyCompat
  get overridden(): boolean {
    return !deepEqual(this.hex, this.default_hex);
  }

  // Whether value has changed since it was last saved.
  @computed("hex")
  get changed(): boolean {
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
  get savedIsOverriden(): boolean {
    if (!this.default_hex) {
      return false;
    }
    return this.originals.hex !== this.default_hex;
  }

  @computed("name")
  get translatedName(): string {
    return i18n(`admin.customize.colors.${this.name}.name`, {
      defaultValue: this.name,
    });
  }

  @computed("name")
  get description(): string {
    return i18n(`admin.customize.colors.${this.name}.description`, {
      defaultValue: "",
    });
  }

  /** Brightness from 0 (darkest) to 255 (brightest), or undefined when hex is not a valid color. */
  @computed("hex")
  get brightness(): number | undefined {
    // A missing hex throws here.
    let hex = this.hex!;
    if (hex.length === 6 || hex.length === 3) {
      hex = normalizeHex(hex);
      return Math.round(
        (parseInt(hex.slice(0, 2), 16) * 299 +
          parseInt(hex.slice(2, 4), 16) * 587 +
          parseInt(hex.slice(4, 6), 16) * 114) /
          1000
      );
    }
  }

  @computed("hex")
  get valid(): boolean {
    return isValidHex(this.hex);
  }

  discardColorChange(): void {
    this.hex = this.originalHex;
  }

  @on("init")
  startTrackingChanges(): void {
    this.set("originals", {
      hex: this.hex || "FFFFFF",
    });

    // force changed property to be recalculated
    this.notifyPropertyChange("hex");
  }

  revert(): void {
    this.set("hex", this.default_hex);
  }

  undo(): void {
    if (this.originals) {
      this.set("hex", this.originals.hex);
    }
  }

  @observes("hex")
  hexValueChanged(): void {
    if (this.hex) {
      this.set("hex", this.hex.toString().replace(/[^0-9a-fA-F]/g, ""));
    }
  }
}
