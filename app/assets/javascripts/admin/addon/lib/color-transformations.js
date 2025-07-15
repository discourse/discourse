// Simplified color transformations for preview purposes
// Currently only implements primary-low and tertiary-low

/**
 * Calculate color brightness using the same formula as dc-color-brightness
 */
function colorBrightness(color) {
  const hex = color.replace("#", "");
  const r = parseInt(hex.substr(0, 2), 16);
  const g = parseInt(hex.substr(2, 2), 16);
  const b = parseInt(hex.substr(4, 2), 16);

  return r * 0.299 + g * 0.587 + b * 0.114;
}

/**
 * Scale a color's lightness (simplified version of Sass color.scale)
 */
function scaleColorLightness(color, lightness) {
  const hex = color.replace("#", "");
  const r = parseInt(hex.substr(0, 2), 16);
  const g = parseInt(hex.substr(2, 2), 16);
  const b = parseInt(hex.substr(4, 2), 16);

  // Simple lightness scaling
  const factor = 1 + lightness / 100;
  const newR = Math.max(0, Math.min(255, Math.round(r * factor)));
  const newG = Math.max(0, Math.min(255, Math.round(g * factor)));
  const newB = Math.max(0, Math.min(255, Math.round(b * factor)));

  return `#${newR.toString(16).padStart(2, "0")}${newG.toString(16).padStart(2, "0")}${newB.toString(16).padStart(2, "0")}`;
}

/**
 * Implementation of dark-light-diff function
 */
function darkLightDiff(adjustedColor, comparisonColor, lightness, darkness) {
  const adjustedBrightness = colorBrightness(adjustedColor);
  const comparisonBrightness = colorBrightness(comparisonColor);

  if (adjustedBrightness < comparisonBrightness) {
    return scaleColorLightness(adjustedColor, lightness);
  } else {
    return scaleColorLightness(adjustedColor, darkness);
  }
}

/**
 * Get primary-low or tertiary-low color for preview
 */
export function getPreviewColor(scheme, colorName) {
  const baseColor = scheme.colors?.find((c) => c.name === colorName);
  const secondaryColor = scheme.colors?.find((c) => c.name === "secondary");

  if (!baseColor || !secondaryColor) {
    return "#f0f0f0"; // light gray fallback
  }

  const base = baseColor.hex;
  const secondary = secondaryColor.hex;

  if (colorName === "primary") {
    // primary-low: dark-light-diff($primary, $secondary, 90%, -78%)
    return darkLightDiff(base, secondary, 90, -78);
  } else if (colorName === "tertiary") {
    // tertiary-low: dark-light-diff($tertiary, $secondary, 85%, -65%)
    return darkLightDiff(base, secondary, 85, -65);
  }

  return base;
}

/**
 * Generate CSS custom properties
 */
export function getColorSchemeStyles(scheme) {
  const primaryLow = getPreviewColor(scheme, "primary");
  const tertiaryLow = getPreviewColor(scheme, "tertiary");

  return `--primary-low--preview: ${primaryLow}; --tertiary-low--preview: ${tertiaryLow};`;
}
