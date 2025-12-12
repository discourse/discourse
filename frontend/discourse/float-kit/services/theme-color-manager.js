import Service from "@ember/service";

/**
 * ThemeColorManager Service
 *
 * Manages theme-color meta tag ownership
 * across multiple sheets. Ensures proper stacking and restoration of theme
 * colors when sheets open/close.
 */
export default class ThemeColorManager extends Service {
  // ============================================================================
  // Ownership Stack
  // ============================================================================

  /**
   * Stack of theme color ownership entries.
   * Each entry: { controller, previousContent }
   */
  ownershipStack = [];

  // ============================================================================
  // Color Parsing Utilities
  // ============================================================================

  /**
   * Parse a color string into RGB components and alpha.
   * Supports hex (#RGB, #RRGGBB) and rgb/rgba formats.
   *
   * @param {string} colorStr - Color string to parse
   * @returns {{ rgb: number[], alpha: number } | null}
   */
  parseColor(colorStr) {
    if (!colorStr) {
      return null;
    }

    let r, g, b;
    let alpha = 1;

    if (colorStr.startsWith("#")) {
      const hex = colorStr.slice(1);
      if (hex.length === 3) {
        r = parseInt(hex[0] + hex[0], 16);
        g = parseInt(hex[1] + hex[1], 16);
        b = parseInt(hex[2] + hex[2], 16);
      } else if (hex.length === 6) {
        r = parseInt(hex.slice(0, 2), 16);
        g = parseInt(hex.slice(2, 4), 16);
        b = parseInt(hex.slice(4, 6), 16);
      } else {
        return null;
      }
    } else if (colorStr.startsWith("rgb")) {
      const match = colorStr
        .replace(/\s+/g, "")
        .match(/^rgba?\(([\d.]+),([\d.]+),([\d.]+)(?:,([\d.]+))?\)$/i);

      if (!match) {
        return null;
      }

      r = parseFloat(match[1]);
      g = parseFloat(match[2]);
      b = parseFloat(match[3]);
      alpha = match[4] !== undefined ? parseFloat(match[4]) : 1;
    } else {
      return null;
    }

    return { rgb: [r, g, b], alpha };
  }

  /**
   * Mix two colors together with a given alpha.
   *
   * @param {string} baseColorStr - Base color string
   * @param {string} overlayColorStr - Overlay color string
   * @param {number} alpha - Mix alpha (0-1)
   * @returns {string} Mixed color as rgb() string
   */
  mixColor(baseColorStr, overlayColorStr, alpha) {
    const base = this.parseColor(baseColorStr);
    const overlay = this.parseColor(overlayColorStr);

    if (!base || !overlay) {
      return baseColorStr;
    }

    const mixAlpha = Math.min(Math.max(alpha ?? overlay.alpha ?? 1, 0), 1);

    const r = Math.round(
      (1 - mixAlpha) * base.rgb[0] + mixAlpha * overlay.rgb[0]
    );
    const g = Math.round(
      (1 - mixAlpha) * base.rgb[1] + mixAlpha * overlay.rgb[1]
    );
    const b = Math.round(
      (1 - mixAlpha) * base.rgb[2] + mixAlpha * overlay.rgb[2]
    );

    return `rgb(${r}, ${g}, ${b})`;
  }

  /**
   * Check if a color string is usable for theme color.
   * Colors with alpha < 1 are not usable.
   *
   * @param {string} colorStr - Color string to check
   * @returns {boolean}
   */
  isUsableThemeColor(colorStr) {
    const parsed = this.parseColor(colorStr);
    if (!parsed) {
      return false;
    }
    return parsed.alpha === undefined || parsed.alpha >= 1;
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

    // Calculate target color
    let targetColor = controller.underlyingThemeColor;

    if (controller.themeColorDimmingOverlays.length > 0 && targetColor) {
      // Use the last overlay's alpha for dimming
      const overlay =
        controller.themeColorDimmingOverlays[
          controller.themeColorDimmingOverlays.length - 1
        ];
      if (overlay) {
        targetColor = this.mixColor(targetColor, overlay.color, overlay.alpha);
      }
    }

    if (targetColor) {
      metaTag.setAttribute("content", targetColor);
    }
  }

  /**
   * Register a theme color dimming overlay for a controller.
   *
   * @param {Object} controller - The controller registering the overlay
   * @param {Object} overlay - The overlay { color, alpha }
   * @returns {{ updateAlpha: Function, remove: Function }}
   */
  registerThemeColorDimmingOverlay(controller, overlay) {
    controller.themeColorDimmingOverlays.push(overlay);
    this.setActualThemeColor(controller);

    return {
      updateAlpha: (alpha) => {
        overlay.alpha = alpha;
        this.setActualThemeColor(controller);
      },
      remove: () => {
        controller.themeColorDimmingOverlays =
          controller.themeColorDimmingOverlays.filter((o) => o !== overlay);
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

