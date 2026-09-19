export function loopBodyPath(start, end, side) {
  const dy = end.y - start.y;
  const bow = Math.max(40, Math.abs(dy) * 0.25);
  const offset = side === "right" ? bow : -bow;

  return `M ${start.x} ${start.y} C ${start.x + offset} ${start.y}, ${end.x + offset} ${end.y}, ${end.x} ${end.y}`;
}

export function loopBackLayout(start, end, padding = 40) {
  const bottomY = Math.max(start.y, end.y) + padding;
  const midX = (start.x + end.x) / 2;

  return {
    d: [
      `M ${start.x} ${start.y}`,
      `C ${start.x + 20} ${start.y}, ${start.x + 20} ${bottomY}, ${start.x} ${bottomY}`,
      `L ${end.x} ${bottomY}`,
      `C ${end.x - 20} ${bottomY}, ${end.x - 20} ${end.y}, ${end.x} ${end.y}`,
    ].join(" "),
    arrowPoints: `${midX},${bottomY} ${midX + 4},${bottomY + 6} ${midX - 4},${bottomY + 6}`,
    buttonPosition: {
      x: midX - 14,
      y: bottomY + 8,
    },
  };
}
