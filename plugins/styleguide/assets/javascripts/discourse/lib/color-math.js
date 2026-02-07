function hexToRgb(hex) {
  hex = hex.replace(/^#/, "");
  if (hex.length === 3) {
    hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
  }
  return [
    parseInt(hex.substring(0, 2), 16),
    parseInt(hex.substring(2, 4), 16),
    parseInt(hex.substring(4, 6), 16),
  ];
}

function rgbToHex(rgb) {
  return (
    "#" + rgb.map((c) => Math.round(c).toString(16).padStart(2, "0")).join("")
  );
}

function rgbToHsl(r, g, b) {
  r /= 255;
  g /= 255;
  b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h;
  let s;
  const l = (max + min) / 2;

  if (max === min) {
    h = 0;
    s = 0;
  } else {
    const d = max - min;
    s = l >= 0.5 ? d / (2 - max - min) : d / (max + min);
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

  return [Math.round(h * 360), Math.round(s * 100), Math.round(l * 100)];
}

function hueToRgb(p, q, t) {
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
}

function hslToRgb(h, s, l) {
  h /= 360;
  s /= 100;
  l /= 100;

  let r, g, b;

  if (s === 0) {
    r = g = b = l;
  } else {
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hueToRgb(p, q, h + 1 / 3);
    g = hueToRgb(p, q, h);
    b = hueToRgb(p, q, h - 1 / 3);
  }

  return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
}

function brightness(hex) {
  const [r, g, b] = hexToRgb(hex);
  return (r * 299 + g * 587 + b * 114) / 1000;
}

function scaleColorLightness(hex, adjustment) {
  const rgb = hexToRgb(hex);
  const [h, s, l] = rgbToHsl(...rgb);
  const newL = adjustment > 0 ? l + (100 - l) * adjustment : l + l * adjustment;
  return rgbToHex(hslToRgb(h, s, Math.max(0, Math.min(100, newL))));
}

export function darkLightDiff(adjustedHex, comparisonHex, lightness, darkness) {
  if (brightness(adjustedHex) < brightness(comparisonHex)) {
    return scaleColorLightness(adjustedHex, lightness);
  } else {
    return scaleColorLightness(adjustedHex, darkness);
  }
}

export function cssToHex(value) {
  const rgbMatch = value.match(
    /rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)/
  );
  if (rgbMatch) {
    return rgbToHex([
      Math.round(parseFloat(rgbMatch[1])),
      Math.round(parseFloat(rgbMatch[2])),
      Math.round(parseFloat(rgbMatch[3])),
    ]);
  }
  let hex = value.replace(/^#/, "");
  if (hex.length === 3) {
    hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
  }
  if (/^[0-9a-f]{6,8}$/i.test(hex)) {
    return "#" + hex.substring(0, 6).toLowerCase();
  }
  return null;
}

// Derivative color definitions: maps base CSS variable names to their
// derivative variables with the light/dark ratios from color_transformations.scss.
// Each entry: [cssVarName, lightRatio, darkRatio]
const DERIVATIVE_MAP = {
  "--primary": {
    comparison: "--secondary",
    derivatives: [
      ["--primary-very-low", 0.97, -0.82],
      ["--primary-low", 0.9, -0.78],
      ["--primary-low-mid", 0.7, -0.45],
      ["--primary-medium", 0.5, -0.35],
      ["--primary-high", 0.3, -0.25],
      ["--primary-50", 0.97, -0.82],
      ["--primary-100", 0.94, -0.8],
      ["--primary-200", 0.9, -0.78],
      ["--primary-300", 0.8, -0.6],
      ["--primary-400", 0.7, -0.45],
      ["--primary-500", 0.6, -0.4],
      ["--primary-600", 0.5, -0.35],
      ["--primary-700", 0.38, -0.3],
      ["--primary-800", 0.3, -0.25],
      ["--primary-900", 0.15, -0.1],
    ],
  },
  "--secondary": {
    comparison: "--primary",
    derivatives: [
      ["--secondary-low", 0.7, -0.7],
      ["--secondary-medium", 0.5, -0.5],
      ["--secondary-high", 0.3, -0.35],
    ],
  },
  "--tertiary": {
    comparison: "--secondary",
    derivatives: [
      ["--tertiary-low", 0.85, -0.65],
      ["--tertiary-medium", 0.5, -0.45],
      ["--tertiary-high", 0.2, -0.25],
      ["--tertiary-25", 0.93, -0.8],
      ["--tertiary-50", 0.9, -0.75],
      ["--tertiary-100", 0.88, -0.72],
      ["--tertiary-200", 0.87, -0.69],
      ["--tertiary-300", 0.85, -0.65],
      ["--tertiary-400", 0.74, -0.58],
      ["--tertiary-500", 0.63, -0.52],
      ["--tertiary-600", 0.5, -0.45],
      ["--tertiary-700", 0.4, -0.38],
      ["--tertiary-800", 0.3, -0.31],
      ["--tertiary-900", 0.2, -0.25],
    ],
  },
  "--quaternary": {
    comparison: "--secondary",
    derivatives: [["--quaternary-low", 0.7, -0.7]],
  },
  "--highlight": {
    comparison: "--secondary",
    derivatives: [["--highlight-bg", 0.7, -0.8]],
  },
  "--danger": {
    comparison: "--secondary",
    derivatives: [
      ["--danger-low", 0.9, -0.68],
      ["--danger-medium", 0.3, -0.35],
    ],
  },
  "--success": {
    comparison: "--secondary",
    derivatives: [
      ["--success-low", 0.8, -0.6],
      ["--success-medium", 0.5, -0.4],
    ],
  },
  "--love": {
    comparison: "--secondary",
    derivatives: [["--love-low", 0.85, -0.6]],
  },
};

export function getDerivativeMap() {
  return DERIVATIVE_MAP;
}
