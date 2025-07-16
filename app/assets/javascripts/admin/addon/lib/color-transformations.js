// replicates colors transformations from variables.scss
// so we can generate transformed colors from color schemes in JS
// currently only generates primary-low and tertiary-low

// normalize hex color to 6 digits
function normalizeHex(hex) {
  hex = hex.replace("#", "");
  if (hex.length === 3) {
    return hex
      .split("")
      .map((c) => c + c)
      .join("");
  }
  return hex;
}

// matches dc-color-brightness from variables.scss
function colorBrightness(color) {
  const hex = normalizeHex(color);
  const r = parseInt(hex.substr(0, 2), 16);
  const g = parseInt(hex.substr(2, 2), 16);
  const b = parseInt(hex.substr(4, 2), 16);

  return r * 0.299 + g * 0.587 + b * 0.114;
}

// convert RGB to HSL
function rgbToHsl(r, g, b) {
  r /= 255;
  g /= 255;
  b /= 255;

  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h,
    s,
    l = (max + min) / 2;

  if (max === min) {
    h = s = 0;
  } else {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r:
        h = (g - b) / d + (g < b ? 6 : 0);
        break;
      case g:
        h = (b - r) / d + 2;
        break;
      case b:
        h = (r - g) / d + 4;
        break;
    }
    h /= 6;
  }

  return [h, s, l];
}

// HSL to RGB
function hslToRgb(h, s, l) {
  let r, g, b;

  if (s === 0) {
    r = g = b = l;
  } else {
    const hue2rgb = (p, q, t) => {
      if (t < 0) {
        t += 1;
      }
      if (t > 1) {
        t -= 1;
      }
      if (t < 1 / 6) {
        return p + (q - p) * 6 * t;
      }
      if (t < 1 / 2) {
        return q;
      }
      if (t < 2 / 3) {
        return p + (q - p) * (2 / 3 - t) * 6;
      }
      return p;
    };

    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }

  return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
}

// scale color lightness (approximates sass' scale-color)
function scaleColorLightness(color, lightness) {
  const hex = normalizeHex(color);
  const r = parseInt(hex.substr(0, 2), 16);
  const g = parseInt(hex.substr(2, 2), 16);
  const b = parseInt(hex.substr(4, 2), 16);

  // convert to HSL
  const [h, s, l] = rgbToHsl(r, g, b);

  // scale lightness similar to sass
  let newL;
  if (lightness > 0) {
    newL = l + (1 - l) * (lightness / 100);
  } else {
    newL = l * (1 + lightness / 100);
  }

  const [newR, newG, newB] = hslToRgb(h, s, newL);

  return `#${newR.toString(16).padStart(2, "0")}${newG.toString(16).padStart(2, "0")}${newB.toString(16).padStart(2, "0")}`;
}

function darkLightDiff(adjustedColor, comparisonColor, lightness, darkness) {
  const adjustedBrightness = colorBrightness(adjustedColor);
  const comparisonBrightness = colorBrightness(comparisonColor);

  if (adjustedBrightness < comparisonBrightness) {
    return scaleColorLightness(adjustedColor, lightness);
  } else {
    return scaleColorLightness(adjustedColor, darkness);
  }
}

// get primary-low or tertiary-low color for preview
export function getPreviewColor(scheme, colorName) {
  const baseColor = scheme.colors?.find((c) => c.name === colorName);
  const secondaryColor = scheme.colors?.find((c) => c.name === "secondary");

  if (!baseColor || !secondaryColor) {
    return "#ffffff"; // fallback
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

// generate CSS custom properties
export function getColorSchemeStyles(scheme) {
  const primaryLow = getPreviewColor(scheme, "primary");
  const tertiaryLow = getPreviewColor(scheme, "tertiary");

  return `--primary-low--preview: ${primaryLow}; --tertiary-low--preview: ${tertiaryLow};`;
}
