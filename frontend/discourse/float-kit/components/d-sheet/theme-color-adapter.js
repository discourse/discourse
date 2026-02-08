import { guidFor } from "@ember/object/internals";
import { capabilities } from "discourse/services/capabilities";

export default class ThemeColorAdapter {
  dimmingOverlayId;
  themeColorDimming = false;
  themeColorDimmingAlpha = null;

  constructor() {
    this.dimmingOverlayId = guidFor(this);
  }

  get effectiveThemeColorDimming() {
    if (this.themeColorDimming === "auto") {
      return (
        capabilities.isWebKit && !capabilities.isStandaloneWithBlackTranslucent
      );
    }
    return Boolean(this.themeColorDimming);
  }

  configure(options) {
    if (options.themeColorDimming !== undefined) {
      this.themeColorDimming = options.themeColorDimming;
    }
    if (options.themeColorDimmingAlpha !== undefined) {
      this.themeColorDimmingAlpha = options.themeColorDimmingAlpha;
    }
  }
}
