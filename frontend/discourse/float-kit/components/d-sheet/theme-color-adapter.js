/**
 * Adapter for managing mobile browser theme-color meta tag behavior in d-sheet modals.
 * Coordinates with ThemeColorManager to handle dimming overlays during sheet presentation,
 * captures theme colors from sheet content backgrounds, and maintains a stack-based ownership
 * model for nested sheets. Supports auto-detection of WebKit capabilities and configurable
 * dimming alpha values for visual sheet hierarchy.
 */

import { capabilities } from "discourse/services/capabilities";

/**
 * Manages theme color behavior for sheets including dimming overlays,
 * meta tag ownership, and color capture from content elements.
 */
export default class ThemeColorAdapter {
  /** @type {import("./controller").default} */
  controller;

  /** @type {boolean | string} */
  themeColorDimming = false;

  /** @type {number | null} */
  themeColorDimmingAlpha = null;

  /** @type {HTMLMetaElement | null} */
  themeColorMetaTag = null;

  /** @type {{controller: ThemeColorAdapter, previousContent: string} | null} */
  themeColorStackEntry = null;

  /** @type {string | null} */
  underlyingThemeColor = null;

  /**
   * @param {import("./controller").default} controller
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Proxies the theme color manager service from the controller.
   *
   * @type {import("../../services/theme-color-manager").default | null}
   */
  get themeColorManager() {
    return this.controller.themeColorManager;
  }

  /**
   * Proxies the sheet's content element from the controller.
   *
   * @type {HTMLElement | null}
   */
  get content() {
    return this.controller.content;
  }

  /**
   * Whether theme color dimming is effectively enabled.
   * When set to "auto", checks WebKit capabilities.
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
   * Applies theme color settings from the provided options.
   *
   * @param {Object} options
   * @param {boolean | string} [options.themeColorDimming]
   * @param {number} [options.themeColorDimmingAlpha]
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
   * Registers a theme color dimming overlay via the manager.
   *
   * @param {{color: string, alpha: number}} overlay
   * @returns {{updateAlpha: (alpha: number) => void, remove: () => void} | undefined}
   */
  registerThemeColorDimmingOverlay(overlay) {
    return this.themeColorManager?.registerThemeColorDimmingOverlay(
      this,
      overlay
    );
  }

  /**
   * Releases ownership of the theme color via the manager.
   *
   * @returns {void}
   */
  releaseThemeColorOwnership() {
    this.themeColorManager?.releaseThemeColorOwnership(this);
  }

  /**
   * Captures the theme color from the content element's background.
   *
   * @returns {void}
   */
  captureContentThemeColor() {
    this.themeColorManager?.captureContentThemeColor(this);
  }

  /**
   * Cleans up theme color resources by releasing ownership.
   *
   * @returns {void}
   */
  cleanup() {
    this.releaseThemeColorOwnership();
  }
}
