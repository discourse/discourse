import Service from "@ember/service";

/**
 * Service to manage the theme-color meta tag.
 * Handles stacking and dimming across multiple sheets.
 * Strictly follows the internal implementation for color logic.
 */
export default class ThemeColorManager extends Service {
  /**
   * Stack of theme color ownership entries.
   * Each entry: { controller, previousContent }
   * @type {Array<{controller: Object, previousContent: string}>}
   */
  ownershipStack = [];

  /**
   * Global list of theme color dimming overlays.
   * @type {Array<{controller: Object, color: number[], alpha: number}>}
   */
  dimmingOverlays = [];

  // ============================================================================
  // ============================================================================

  /**
   * Parses an RGB/RGBA string into an array of [r, g, b].
   *
   * @param {string} colorStr
   * @returns {number[]|null}
   */
  #parseRGB(colorStr) {
    if (!colorStr) {
      return null;
    }

    return (colorStr.startsWith("rgb(") || colorStr.startsWith("rgba(")) &&
      colorStr.endsWith(")")
      ? colorStr
          .substring(colorStr.indexOf("(") + 1, colorStr.indexOf(")"))
          .split(",")
          .map((c) => c.trim())
          .slice(0, 3)
          .map((c) => parseFloat(c))
      : null;
  }

  /**
   * Parses a color string (RGB, RGBA, or Hex) into an array of [r, g, b].
   * Strictly follows the internal color parsing implementation.
   *
   * @param {string} colorStr
   * @returns {number[]|null}
   */
  #parseColor(colorStr) {
    if (!colorStr) {
      return null;
    }

    let result = null;
    if (colorStr.startsWith("rgb(") || colorStr.startsWith("rgba(")) {
      result = this.#parseRGB(colorStr);
    } else if (colorStr.startsWith("#")) {
      let hex = colorStr.replace(/^#/, "");
      let normalizedHex =
        hex.length === 3 ? hex.split("").map((h) => h + h).join("") : hex;

      result = /^[0-9A-Fa-f]{6}$/.test(normalizedHex)
        ? [
            parseInt(normalizedHex.slice(0, 2), 16),
            parseInt(normalizedHex.slice(2, 4), 16),
            parseInt(normalizedHex.slice(4, 6), 16),
          ]
        : null;
    }
    return result;
  }

  /**
   * Mixes a base color with multiple overlays.
   *
   * @param {number[]} baseColor - [r, g, b]
   * @param {Array<{color: number[], alpha: number}>} overlays
   * @returns {string} rgb() string
   */
  #mixColors(baseColor, overlays) {
    let result = [...baseColor];
    for (let i = 0; i < overlays.length; i++) {
      const overlay = overlays[i];
      const alpha = overlay.alpha;
      for (let j = 0; j < 3; j++) {
        result[j] = (1 - alpha) * result[j] + alpha * overlay.color[j];
      }
    }
    return `rgb(${result.join(",")})`;
  }

  /**
   * Check if a color string is usable for theme color.
   *
   * @param {string} colorStr - Color string to check
   * @returns {boolean}
   */
  isUsableThemeColor(colorStr) {
    return Boolean(this.#parseColor(colorStr));
  }

  // ============================================================================
  // Meta Tag Management
  // ============================================================================

  /**
   * Find the currently active theme-color meta tag.
   * Prioritizes tags with matching media queries.
   *
   * @returns {HTMLMetaElement | null}
   */
  findActiveThemeColorMetaTag() {
    if (typeof document === "undefined") {
      return null;
    }

    const metaTags = document.querySelectorAll('meta[name="theme-color"]');

    if (!metaTags.length) {
      return null;
    }

    let fallback = null;

    for (const meta of metaTags) {
      if (!meta.media) {
        fallback = fallback || meta;
        continue;
      }

      try {
        if (
          typeof window === "undefined" ||
          window.matchMedia(meta.media).matches
        ) {
          return meta;
        }
      } catch {
        // Ignore invalid media queries
      }
    }

    return fallback || metaTags[0];
  }

  /**
   * Ensure a theme-color meta tag exists.
   * Creates one if none exists.
   *
   * @param {Object} controller - The controller requesting the meta tag
   * @returns {HTMLMetaElement | null}
   */
  ensureThemeColorMetaTag(controller) {
    if (typeof document === "undefined") {
      return null;
    }

    if (
      controller.themeColorMetaTag &&
      document.contains(controller.themeColorMetaTag)
    ) {
      return controller.themeColorMetaTag;
    }

    controller.themeColorMetaTag = this.findActiveThemeColorMetaTag();

    if (!controller.themeColorMetaTag) {
      const meta = document.createElement("meta");
      meta.name = "theme-color";
      const fallback =
        typeof window !== "undefined"
          ? window.getComputedStyle(document.body)?.backgroundColor
          : "#000000";
      meta.setAttribute("content", fallback || "#000000");
      document.head.appendChild(meta);
      controller.themeColorMetaTag = meta;
    }

    return controller.themeColorMetaTag;
  }

  // ============================================================================
  // Ownership Management
  // ============================================================================

  /**
   * Check if a controller currently controls the theme color.
   *
   * @param {Object} controller - The controller to check
   * @returns {boolean}
   */
  controlsThemeColor(controller) {
    if (!controller.themeColorStackEntry) {
      return false;
    }

    const topEntry = this.ownershipStack[this.ownershipStack.length - 1];
    return topEntry?.controller === controller;
  }

  /**
   * Acquire theme color ownership for a controller.
   * Moves existing entry to top if already in stack.
   *
   * @param {Object} controller - The controller acquiring ownership
   */
  acquireThemeColorOwnership(controller) {
    if (controller.themeColorStackEntry) {
      if (this.controlsThemeColor(controller)) {
        return;
      }

      const idx = this.ownershipStack.findIndex(
        (entry) => entry === controller.themeColorStackEntry
      );
      if (idx !== -1) {
        this.ownershipStack.splice(idx, 1);
      }
      controller.themeColorStackEntry = null;
    }

    const metaTag = this.ensureThemeColorMetaTag(controller);
    if (!metaTag) {
      return;
    }

    const entry = {
      controller,
      previousContent: metaTag.getAttribute("content"),
    };

    this.ownershipStack.push(entry);
    controller.themeColorStackEntry = entry;
  }

  /**
   * Release theme color ownership for a controller.
   * Restores previous color if this was the top entry.
   *
   * @param {Object} controller - The controller releasing ownership
   */
  releaseThemeColorOwnership(controller) {
    if (!controller.themeColorStackEntry) {
      return;
    }

    const idx = this.ownershipStack.findIndex(
      (entry) => entry === controller.themeColorStackEntry
    );

    if (idx === -1) {
      controller.themeColorStackEntry = null;
      return;
    }

    const wasTop = idx === this.ownershipStack.length - 1;
    const [entry] = this.ownershipStack.splice(idx, 1);
    controller.themeColorStackEntry = null;
    controller.underlyingThemeColor = null;

    // Ensure all overlays for this controller are removed when ownership is released
    this.dimmingOverlays = this.dimmingOverlays.filter(
      (o) => o.controller !== controller
    );

    if (wasTop) {
      const nextEntry = this.ownershipStack[this.ownershipStack.length - 1];

      if (nextEntry) {
        this.setActualThemeColor(nextEntry.controller);
      } else if (entry.previousContent && controller.themeColorMetaTag) {
        controller.themeColorMetaTag.setAttribute(
          "content",
          entry.previousContent
        );
      }
    }
  }

  // ============================================================================
  // Theme Color Updates
  // ============================================================================

  /**
   * Update the theme color for a controller.
   *
   * @param {Object} controller - The controller updating the color
   * @param {string} color - The new color
   */
  updateThemeColor(controller, color) {
    if (!color) {
      return;
    }

    this.acquireThemeColorOwnership(controller);
    controller.underlyingThemeColor = color;
    this.setActualThemeColor(controller);
  }

  /**
   * Set the actual theme color meta tag content.
   * Applies dimming overlays if present.
   *
   * @param {Object} controller - The controller setting the color
   */
  setActualThemeColor(controller) {
    const metaTag = this.ensureThemeColorMetaTag(controller);
    if (!metaTag || !this.controlsThemeColor(controller)) {
      return;
    }

    // Capture existing color from DOM if we haven't stored one yet
    if (!controller.underlyingThemeColor) {
      controller.underlyingThemeColor = metaTag.getAttribute("content");
    }

    const baseColor = this.#parseColor(controller.underlyingThemeColor);
    if (!baseColor) {
      return;
    }

    const targetColorStr = this.#mixColors(baseColor, this.dimmingOverlays);
    metaTag.setAttribute("content", targetColorStr);
  }

  /**
   * Register a theme color dimming overlay for a controller.
   *
   * @param {Object} controller - The controller registering the overlay
   * @param {Object} overlay - The overlay { color, alpha }
   * @returns {{ updateAlpha: Function, remove: Function }}
   */
  registerThemeColorDimmingOverlay(controller, overlay) {
    const overlayEntry = {
      ...overlay,
      color: this.#parseColor(overlay.color) || [0, 0, 0],
      controller,
    };

    this.dimmingOverlays.push(overlayEntry);
    this.setActualThemeColor(controller);

    return {
      updateAlpha: (alpha) => {
        overlayEntry.alpha = alpha;
        this.setActualThemeColor(controller);
      },
      remove: () => {
        this.dimmingOverlays = this.dimmingOverlays.filter(
          (o) => o !== overlayEntry
        );
        this.setActualThemeColor(controller);
      },
    };
  }

  /**
   * Capture the theme color from content element's background.
   *
   * @param {Object} controller - The controller to capture for
   */
  captureContentThemeColor(controller) {
    if (!controller.content || typeof window === "undefined") {
      return;
    }

    const computedColor = window
      .getComputedStyle(controller.content)
      ?.getPropertyValue("background-color");

    if (this.isUsableThemeColor(computedColor)) {
      this.updateThemeColor(controller, computedColor);
      return;
    }

    const fallback = this.ensureThemeColorMetaTag(controller)?.getAttribute(
      "content"
    );
    if (fallback) {
      this.updateThemeColor(controller, fallback);
    }
  }
}
