import Service from "@ember/service";

export default class ThemeColorManager extends Service {
  themeColorMetaTag = null;
  underlyingThemeColor = null;
  themeColorDimmingOverlays = [];

  #parseRGB(colorStr) {
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

  #parseColor(colorStr) {
    if (!colorStr) {
      return null;
    }

    if (colorStr.startsWith("rgb(") || colorStr.startsWith("rgba(")) {
      return this.#parseRGB(colorStr);
    }

    if (colorStr.startsWith("#")) {
      const hex = colorStr.replace(/^#/, "");
      const normalized =
        hex.length === 3
          ? hex
              .split("")
              .map((h) => h + h)
              .join("")
          : hex;

      return /^[0-9A-Fa-f]{6}$/.test(normalized)
        ? [
            parseInt(normalized.slice(0, 2), 16),
            parseInt(normalized.slice(2, 4), 16),
            parseInt(normalized.slice(4, 6), 16),
          ]
        : null;
    }

    return null;
  }

  #mixColors(baseColor, overlays) {
    const result = [...baseColor];
    for (let i = 0; i < overlays.length; i++) {
      const alpha = overlays[i].alpha;
      for (let j = 0; j < 3; j++) {
        result[j] = (1 - alpha) * result[j] + alpha * overlays[i].color[j];
      }
    }
    return `rgb(${result.join(",")})`;
  }

  storeThemeColorMetaTag() {
    this.themeColorMetaTag =
      typeof document !== "undefined"
        ? document.querySelector('meta[name="theme-color"]')
        : null;

    if (!this.themeColorMetaTag) {
      const meta = document.createElement("meta");
      meta.name = "theme-color";
      meta.content = window.getComputedStyle(document.body).backgroundColor;
      document.head.appendChild(meta);
      this.themeColorMetaTag = meta;
    }
  }

  getAndStoreUnderlyingThemeColorAsRGBArray() {
    if (this.themeColorDimmingOverlays.length > 0) {
      return this.underlyingThemeColor;
    }

    this.themeColorMetaTag || this.storeThemeColorMetaTag();

    const parsed = this.#parseColor(this.themeColorMetaTag?.content);
    if (!parsed) {
      // eslint-disable-next-line no-console
      console.warn(
        "`themeColorDimming` prop ignored: Only `theme-color` meta tag with a value in `rgb()`, `rgba()`, or hexadecimal format is supported."
      );
    }

    this.underlyingThemeColor = parsed;
    return parsed;
  }

  updateUnderlyingThemeColor(color) {
    const parsed = this.#parseColor(color);
    if (!parsed) {
      throw new Error(
        "The color provided to `updateThemeColor` doesn't match `rgb()`, `rgba()`, or hexadecimal format."
      );
    }

    this.underlyingThemeColor = parsed;
    this.setActualThemeColor();
  }

  setActualThemeColor() {
    this.themeColorMetaTag || this.storeThemeColorMetaTag();
    this.themeColorMetaTag?.setAttribute(
      "content",
      this.#mixColors(this.underlyingThemeColor, this.themeColorDimmingOverlays)
    );
  }

  updateThemeColorDimmingOverlay(overlayData) {
    const entry = overlayData.color
      ? { ...overlayData, color: this.#parseRGB(overlayData.color) }
      : overlayData;

    const existing = this.themeColorDimmingOverlays.find(
      (o) => o.dimmingOverlayId === entry.dimmingOverlayId
    );

    let result;
    if (existing) {
      Object.assign(existing, entry);
      result = existing;
    } else {
      result = entry;
      this.themeColorDimmingOverlays.push(entry);
    }

    this.setActualThemeColor();
    return result;
  }

  updateThemeColorDimmingOverlayAlphaValue(overlay, alpha) {
    overlay.alpha = alpha;
    this.setActualThemeColor();
  }

  removeThemeColorDimmingOverlay(dimmingOverlayId) {
    const overlay = this.themeColorDimmingOverlays.find(
      (o) => o.dimmingOverlayId === dimmingOverlayId
    );

    if (!overlay) {
      return;
    }

    overlay.abortRemoval = false;

    setTimeout(() => {
      if (overlay.abortRemoval) {
        return;
      }

      this.themeColorDimmingOverlays = this.themeColorDimmingOverlays.filter(
        (o) => o.dimmingOverlayId !== dimmingOverlayId
      );
      this.setActualThemeColor();

      if (this.themeColorDimmingOverlays.length === 0) {
        this.underlyingThemeColor = null;
        this.themeColorMetaTag = null;
      }
    }, 20);
  }
}
