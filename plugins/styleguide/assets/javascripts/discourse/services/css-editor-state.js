import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import {
  cssToHex,
  darkLightDiff,
  getDerivativeMap,
  getHorizonDerivativeMap,
} from "../lib/color-math";
import {
  getAllCssVariables,
  getBaseColors,
} from "../lib/css-variables-registry";

function toFullHex(value) {
  // Handle rgb() and rgba() — including modern space-separated syntax
  const rgbMatch = value.match(
    /rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)[\s,/]*[\d.]*%?\s*\)/
  );
  if (rgbMatch) {
    const r = Math.round(parseFloat(rgbMatch[1]));
    const g = Math.round(parseFloat(rgbMatch[2]));
    const b = Math.round(parseFloat(rgbMatch[3]));
    return "#" + [r, g, b].map((c) => c.toString(16).padStart(2, "0")).join("");
  }

  // Handle short hex (#RGB or #RGBA) → expand to #RRGGBB
  const shortMatch = value.match(/^#([0-9a-f])([0-9a-f])([0-9a-f])[0-9a-f]?$/i);
  if (shortMatch) {
    return (
      "#" +
      shortMatch[1] +
      shortMatch[1] +
      shortMatch[2] +
      shortMatch[2] +
      shortMatch[3] +
      shortMatch[3]
    ).toLowerCase();
  }

  // Handle 8-digit hex (#RRGGBBAA) → strip alpha to #RRGGBB
  const longAlphaMatch = value.match(/^(#[0-9a-f]{6})[0-9a-f]{2}$/i);
  if (longAlphaMatch) {
    return longAlphaMatch[1].toLowerCase();
  }

  // Already #RRGGBB or non-color value — return as-is
  return value;
}

function brightness(hex) {
  hex = hex.replace(/^#/, "");
  if (hex.length === 3) {
    hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
  }
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);
  return (r * 299 + g * 587 + b * 114) / 1000;
}

const BASE_COLOR_NAMES = new Set(getBaseColors().map((c) => c.name));

export default class CssEditorState extends Service {
  @tracked isOpen = false;
  @tracked isDark = false;

  overrides = new TrackedMap();
  originalValues = new Map();
  initialized = false;

  initialize() {
    if (this.initialized) {
      return;
    }
    this.initialized = true;

    const computedStyle = getComputedStyle(document.documentElement);

    // Capture all CSS variables (base + semantic + styling)
    for (const variable of getAllCssVariables()) {
      const value = computedStyle.getPropertyValue(variable.name).trim();
      this.originalValues.set(variable.name, value);
    }

    // Also capture base colors that might not be in the CSS_VARIABLES list
    for (const baseColor of getBaseColors()) {
      if (!this.originalValues.has(baseColor.name)) {
        const value = computedStyle.getPropertyValue(baseColor.name).trim();
        this.originalValues.set(baseColor.name, value);
      }
    }

    this._updateIsDark();
  }

  _updateIsDark() {
    const primaryHex = this._resolveHex("--primary");
    const secondaryHex = this._resolveHex("--secondary");
    if (primaryHex && secondaryHex) {
      this.isDark = brightness(primaryHex) > brightness(secondaryHex);
    }
  }

  toggle() {
    this.initialize();
    this.isOpen = !this.isOpen;
  }

  getOriginalValue(name) {
    this.initialize();
    return this.originalValues.get(name) || "";
  }

  getCurrentValue(name) {
    if (this.overrides.has(name)) {
      return this.overrides.get(name);
    }
    return this.getOriginalValue(name);
  }

  getColorHex(name) {
    const value = this.getCurrentValue(name);
    return toFullHex(value);
  }

  _resolveHex(name) {
    const value = this.getCurrentValue(name);
    return cssToHex(value);
  }

  _updateDerivatives(name) {
    const derivativeMap = getDerivativeMap();
    const entry = derivativeMap[name];
    if (entry) {
      const baseHex = this._resolveHex(name);
      const comparisonHex = this._resolveHex(entry.comparison);
      if (baseHex && comparisonHex) {
        for (const [derivName, lightRatio, darkRatio] of entry.derivatives) {
          const computed = darkLightDiff(
            baseHex,
            comparisonHex,
            lightRatio,
            darkRatio
          );
          this.overrides.set(derivName, computed);
          document.documentElement.style.setProperty(derivName, computed);
        }
      }
    }

    this._updateHorizonDerivatives(name);
  }

  _updateHorizonDerivatives(name) {
    const horizonMap = getHorizonDerivativeMap();
    const horizonEntries = horizonMap[name];
    if (!horizonEntries) {
      return;
    }

    const baseHex = this._resolveHex(name);
    const secondaryHex = this._resolveHex("--secondary");
    if (!baseHex) {
      return;
    }

    for (const { name: derivName, compute } of horizonEntries) {
      const computed = compute(baseHex, secondaryHex, this.isDark);
      this.overrides.set(derivName, computed);
      document.documentElement.style.setProperty(derivName, computed);
    }
  }

  setVariable(name, value) {
    this.overrides.set(name, value);
    document.documentElement.style.setProperty(name, value);

    if (name === "--primary" || name === "--secondary") {
      this._updateIsDark();
    }

    this._updateDerivatives(name);
  }

  resetVariable(name) {
    this.overrides.delete(name);
    document.documentElement.style.removeProperty(name);

    // Reset standard derivatives
    const derivativeMap = getDerivativeMap();
    const entry = derivativeMap[name];
    if (entry) {
      for (const [derivName] of entry.derivatives) {
        this.overrides.delete(derivName);
        document.documentElement.style.removeProperty(derivName);
      }
    }

    // Reset Horizon derivatives
    const horizonMap = getHorizonDerivativeMap();
    const horizonEntries = horizonMap[name];
    if (horizonEntries) {
      for (const { name: derivName } of horizonEntries) {
        this.overrides.delete(derivName);
        document.documentElement.style.removeProperty(derivName);
      }
    }

    if (name === "--primary" || name === "--secondary") {
      this._updateIsDark();
    }
  }

  resetAll() {
    for (const name of this.overrides.keys()) {
      document.documentElement.style.removeProperty(name);
    }
    this.overrides.clear();
    this._updateIsDark();
  }

  get hasOverrides() {
    return this.overrides.size > 0;
  }

  getBaseColorOverrides() {
    const result = [];
    for (const [name, value] of this.overrides) {
      if (BASE_COLOR_NAMES.has(name)) {
        result.push([name, value]);
      }
    }
    return result;
  }

  getCssVariableOverrides() {
    const result = [];
    for (const [name, value] of this.overrides) {
      if (!BASE_COLOR_NAMES.has(name)) {
        result.push([name, value]);
      }
    }
    return result;
  }

  generateThemeCSS() {
    const cssOverrides = this.getCssVariableOverrides();
    if (cssOverrides.length === 0) {
      return "";
    }

    let css = ":root {\n";
    for (const [name, value] of cssOverrides) {
      css += `  ${name}: ${value} !important;\n`;
    }
    css += "}";
    return css;
  }
}
