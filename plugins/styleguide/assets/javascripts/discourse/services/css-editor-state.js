import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import { cssToHex, darkLightDiff, getDerivativeMap } from "../lib/color-math";
import { getAllCssVariables } from "../lib/css-variables-registry";

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

export default class CssEditorState extends Service {
  @tracked isOpen = false;

  overrides = new TrackedMap();
  originalValues = new Map();
  initialized = false;

  initialize() {
    if (this.initialized) {
      return;
    }
    this.initialized = true;

    const computedStyle = getComputedStyle(document.documentElement);
    for (const variable of getAllCssVariables()) {
      const value = computedStyle.getPropertyValue(variable.name).trim();
      this.originalValues.set(variable.name, value);
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
    if (!entry) {
      return;
    }

    const baseHex = this._resolveHex(name);
    const comparisonHex = this._resolveHex(entry.comparison);
    if (!baseHex || !comparisonHex) {
      return;
    }

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

  setVariable(name, value) {
    this.overrides.set(name, value);
    document.documentElement.style.setProperty(name, value);
    this._updateDerivatives(name);
  }

  resetVariable(name) {
    this.overrides.delete(name);
    document.documentElement.style.removeProperty(name);

    // Also reset any derivatives that were auto-computed
    const derivativeMap = getDerivativeMap();
    const entry = derivativeMap[name];
    if (entry) {
      for (const [derivName] of entry.derivatives) {
        this.overrides.delete(derivName);
        document.documentElement.style.removeProperty(derivName);
      }
    }
  }

  resetAll() {
    for (const name of this.overrides.keys()) {
      document.documentElement.style.removeProperty(name);
    }
    this.overrides.clear();
  }

  get hasOverrides() {
    return this.overrides.size > 0;
  }

  get exportCSS() {
    if (this.overrides.size === 0) {
      return "";
    }

    let css = ":root {\n";
    for (const [name, value] of this.overrides) {
      css += `  ${name}: ${value};\n`;
    }
    css += "}";
    return css;
  }
}
