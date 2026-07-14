import { remToPx } from "discourse/lib/rem-to-px";

export const INACTIVE_ALPHA = 0.6;

export function buildLegendIcon(color, isVisible, size = remToPx(1)) {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");

  const borderWidth = 2;
  const half = borderWidth / 2;
  ctx.globalAlpha = isVisible ? 1 : INACTIVE_ALPHA;
  ctx.strokeStyle = color;
  ctx.lineWidth = borderWidth;
  ctx.beginPath();
  ctx.roundRect(half, half, size - borderWidth, size - borderWidth, 4);
  ctx.stroke();

  if (isVisible) {
    const inset = 4;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.roundRect(inset, inset, size - inset * 2, size - inset * 2, 2);
    ctx.fill();
  }

  return canvas;
}

export function dimColor(color, alpha = INACTIVE_ALPHA) {
  const value = color?.trim();
  if (!value) {
    return color;
  }

  if (value.startsWith("#")) {
    let hex = value.slice(1);
    if (hex.length === 3) {
      hex = hex
        .split("")
        .map((char) => char + char)
        .join("");
    }
    const r = parseInt(hex.slice(0, 2), 16);
    const g = parseInt(hex.slice(2, 4), 16);
    const b = parseInt(hex.slice(4, 6), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  const rgbMatch = value.match(/^rgba?\(([^)]+)\)$/);
  if (rgbMatch) {
    const [r, g, b] = rgbMatch[1].split(",").map((part) => part.trim());
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  return value;
}
