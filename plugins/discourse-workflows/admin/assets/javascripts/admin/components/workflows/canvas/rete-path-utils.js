export function bezierPath(start, end) {
  const dx = end.x - start.x;
  const offset = Math.max(80, Math.abs(dx) * 0.4);
  return {
    d: `M ${start.x} ${start.y} C ${start.x + offset} ${start.y}, ${end.x - offset} ${end.y}, ${end.x} ${end.y}`,
    controlPoints: [
      start,
      { x: start.x + offset, y: start.y },
      { x: end.x - offset, y: end.y },
      end,
    ],
  };
}

export function loopBodyPath(start, end, side) {
  const dy = end.y - start.y;
  const bow = Math.max(40, Math.abs(dy) * 0.25);
  const offset = side === "right" ? bow : -bow;

  return {
    d: `M ${start.x} ${start.y} C ${start.x + offset} ${start.y}, ${end.x + offset} ${end.y}, ${end.x} ${end.y}`,
    controlPoints: [
      start,
      { x: start.x + offset, y: start.y },
      { x: end.x + offset, y: end.y },
      end,
    ],
  };
}

function cubicBezierAt(pts, t) {
  const u = 1 - t;
  return {
    x:
      u * u * u * pts[0].x +
      3 * u * u * t * pts[1].x +
      3 * u * t * t * pts[2].x +
      t * t * t * pts[3].x,
    y:
      u * u * u * pts[0].y +
      3 * u * u * t * pts[1].y +
      3 * u * t * t * pts[2].y +
      t * t * t * pts[3].y,
  };
}

function connectionMidpoint(controlPoints) {
  return cubicBezierAt(controlPoints, 0.5);
}

function centeredRectAt(point, width, height) {
  return {
    x: point.x - width / 2,
    y: point.y - height / 2,
  };
}

export function connectionToolbarPosition(controlPoints) {
  return centeredRectAt(connectionMidpoint(controlPoints), 48, 22);
}

function cubicBezierTangentAt(pts, t) {
  const u = 1 - t;
  return {
    x:
      3 * u * u * (pts[1].x - pts[0].x) +
      6 * u * t * (pts[2].x - pts[1].x) +
      3 * t * t * (pts[3].x - pts[2].x),
    y:
      3 * u * u * (pts[1].y - pts[0].y) +
      6 * u * t * (pts[2].y - pts[1].y) +
      3 * t * t * (pts[3].y - pts[2].y),
  };
}

export function positionArrowAtEnd(arrowEl, controlPoints) {
  const t = 0.85;
  const pos = cubicBezierAt(controlPoints, t);
  const tan = cubicBezierTangentAt(controlPoints, t);
  const angle = Math.atan2(tan.y, tan.x) * (180 / Math.PI);
  arrowEl.setAttribute(
    "transform",
    `translate(${pos.x}, ${pos.y}) rotate(${angle})`
  );
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
