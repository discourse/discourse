/*eslint no-bitwise:0 */

export function parseColor(color) {
  const m = color.match(/^#([0-9a-f]{6})$/i);
  if (m) {
    const c = m[1];
    return [
      parseInt(c.slice(0, 2), 16),
      parseInt(c.slice(2, 4), 16),
      parseInt(c.slice(4, 6), 16),
    ];
  }

  return [0, 0, 0];
}

export function brightness(color) {
  return color[0] * 0.299 + color[1] * 0.587 + color[2] * 0.114;
}

function rgbToHsl(r, g, b) {
  r /= 255;
  g /= 255;
  b /= 255;
  let max = Math.max(r, g, b),
    min = Math.min(r, g, b);
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

function hue2rgb(p, q, t) {
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
  let r, g, b;

  if (s === 0) {
    r = g = b = l; // achromatic
  } else {
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }

  return [r * 255, g * 255, b * 255];
}

export function lighten(color, percent) {
  const hsl = rgbToHsl(color[0], color[1], color[2]);
  const scale = percent / 100.0;
  const diff = scale > 0 ? 1.0 - hsl[2] : hsl[2];

  hsl[2] = hsl[2] + diff * scale;
  color = hslToRgb(hsl[0], hsl[1], hsl[2]);

  return (
    "#" +
    (0 | ((1 << 8) + color[0])).toString(16).slice(1) +
    (0 | ((1 << 8) + color[1])).toString(16).slice(1) +
    (0 | ((1 << 8) + color[2])).toString(16).slice(1)
  );
}

export function chooseBrighter(primary, secondary) {
  const primaryCol = parseColor(primary);
  const secondaryCol = parseColor(secondary);
  return brightness(primaryCol) < brightness(secondaryCol)
    ? secondary
    : primary;
}

export function chooseDarker(primary, secondary) {
  if (chooseBrighter(primary, secondary) === primary) {
    return secondary;
  } else {
    return primary;
  }
}

export function darkLightDiff(adjusted, comparison, lightness, darkness) {
  const adjustedCol = parseColor(adjusted);
  const comparisonCol = parseColor(comparison);
  return lighten(
    adjustedCol,
    brightness(adjustedCol) < brightness(comparisonCol) ? lightness : darkness
  );
}

export function drawHeader(ctx, colors, width, headerHeight) {
  ctx.save();
  ctx.beginPath();
  ctx.rect(0, 0, width, headerHeight);
  ctx.fillStyle = colors.header_background;
  ctx.shadowColor = "rgba(0, 0, 0, 0.25)";
  ctx.shadowBlur = 2;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 2;
  ctx.fill();
  ctx.restore();
}

export function resizeTextLinesToFitRect(
  textLines,
  rectWidth,
  ctx,
  fontSize,
  font,
  renderCallback
) {
  const maxLengthLine = textLines.reduce((a, b) =>
    a.length > b.length ? a : b
  );

  let fontSizeDecreaseMultiplier = 1;
  while (ctx.measureText(maxLengthLine).width > rectWidth) {
    fontSizeDecreaseMultiplier -= 0.1;
    ctx.font = `${fontSize * fontSizeDecreaseMultiplier}em '${font}'`;
  }

  for (let i = 0; i < textLines.length; i++) {
    renderCallback(textLines[i], i);
  }
}
