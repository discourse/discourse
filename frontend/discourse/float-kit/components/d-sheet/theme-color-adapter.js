import { capabilities } from "discourse/services/capabilities";

/**
 * Manages theme color behavior for sheets including dimming overlays,
 * meta tag ownership, and color capture from content elements.
 *
 * @class ThemeColorAdapter
 */
export default class ThemeColorAdapter {
  /** @type {Object} The sheet controller instance */
  controller;

  /** @type {boolean|string} Theme color dimming configuration */
  themeColorDimming = false;

  /** @type {number|null} Alpha value for theme color dimming */
  themeColorDimmingAlpha = null;

  /** @type {HTMLMetaElement|null} Theme color meta tag element */
  themeColorMetaTag = null;

  /** @type {Object|null} Entry in the theme color stack */
  themeColorStackEntry = null;

  /** @type {string|null} Original underlying theme color */
  underlyingThemeColor = null;

  /**
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Get the theme color manager service from controller.
   *
   * @returns {Object|null}
   */
  get themeColorManager() {
    return this.controller.themeColorManager;
  }

  /**
   * Access to the sheet's content element.
   *
   * @type {HTMLElement|null}
   */
  get content() {
    return this.controller.content;
  }

  /**
   * Determine if theme color dimming is effectively enabled.
   * When set to "auto", checks browser capabilities.
   *
   * @type {boolean}
   */
  get effectiveThemeColorDimming() {
    if (this.themeColorDimming === "auto") {
      return (
        capabilities.isWebKit && !capabilities.isStandaloneWithBlackTranslucent
      );
    }
    return Boolean(this.themeColorDimming);
  }

  /**
   * Configure theme color settings from options.
   *
   * @param {Object} options - Configuration options
   * @param {boolean|string} options.themeColorDimming - Theme color dimming setting
   * @param {number} options.themeColorDimmingAlpha - Dimming alpha value
   */
  configure(options) {
    if (options.themeColorDimming !== undefined) {
      this.themeColorDimming = options.themeColorDimming;
    }
    if (options.themeColorDimmingAlpha !== undefined) {
      this.themeColorDimmingAlpha = options.themeColorDimmingAlpha;
    }
  }

  /**
   * Update the theme color via the theme color manager.
   *
   * @param {string} color - New theme color value
   */
  updateThemeColor(color) {
    this.themeColorManager?.updateThemeColor(this, color);
  }

  /**
   * Set the actual theme color based on current state.
   */
  setActualThemeColor() {
    this.themeColorManager?.setActualThemeColor(this);
  }

  /**
   * Register a theme color dimming overlay.
   *
   * @param {Object} overlay - Overlay configuration
   * @returns {Object|undefined} Registered overlay handle
   */
  registerThemeColorDimmingOverlay(overlay) {
    return this.themeColorManager?.registerThemeColorDimmingOverlay(
      this,
      overlay
    );
  }

  /**
   * Release ownership of the theme color.
   */
  releaseThemeColorOwnership() {
    this.themeColorManager?.releaseThemeColorOwnership(this);
  }

  /**
   * Capture the theme color from the content element.
   */
  captureContentThemeColor() {
    this.themeColorManager?.captureContentThemeColor(this);
  }

  /**
   * Clean up theme color resources.
   */
  cleanup() {
    this.releaseThemeColorOwnership();
  }
}
