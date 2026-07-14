import { remToPx } from "discourse/lib/rem-to-px";

export function buildLegendIcon(color, isVisible, size = remToPx(1)) {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");

  const borderWidth = 2;
  const half = borderWidth / 2;
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
