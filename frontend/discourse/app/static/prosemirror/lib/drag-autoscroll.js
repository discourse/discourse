const EDGE_SIZE = 32;
const MAX_STEP = 18;

export default function dragAutoscroll(anchor, axis, onScroll) {
  let frame = null;
  let point = null;
  let stopped = false;

  const tick = () => {
    frame = null;
    if (stopped || point === null) {
      return;
    }

    const scroller = scrollTarget(anchor, axis, point);
    if (!scroller) {
      return;
    }

    const property = axis === "X" ? "scrollLeft" : "scrollTop";
    const before = scroller.element[property];
    scroller.element[property] += scroller.delta;
    const change = scroller.element[property] - before;

    if (change) {
      onScroll?.(change);
      frame = requestAnimationFrame(tick);
    }
  };

  return {
    update(event) {
      point = axis === "X" ? event.clientX : event.clientY;
      if (frame === null) {
        frame = requestAnimationFrame(tick);
      }
    },

    stop() {
      stopped = true;
      if (frame !== null) {
        cancelAnimationFrame(frame);
        frame = null;
      }
    },
  };
}

function scrollTarget(anchor, axis, point) {
  const overflowProperty = axis === "X" ? "overflowX" : "overflowY";
  const scrollSize = axis === "X" ? "scrollWidth" : "scrollHeight";
  const clientSize = axis === "X" ? "clientWidth" : "clientHeight";

  for (let element = anchor; element; element = element.parentElement) {
    const overflow = getComputedStyle(element)[overflowProperty];
    if (
      !/(auto|scroll)/.test(overflow) ||
      element[scrollSize] <= element[clientSize]
    ) {
      continue;
    }

    const bounds = element.getBoundingClientRect();
    const start = axis === "X" ? bounds.left : bounds.top;
    const end = axis === "X" ? bounds.right : bounds.bottom;
    const delta = edgeDelta(point, start, end);
    if (delta) {
      return { delta, element };
    }
  }

  return null;
}

function edgeDelta(point, start, end) {
  if (point < start + EDGE_SIZE) {
    return -Math.ceil(
      MAX_STEP * Math.min((start + EDGE_SIZE - point) / EDGE_SIZE, 1)
    );
  }
  if (point > end - EDGE_SIZE) {
    return Math.ceil(
      MAX_STEP * Math.min((point - (end - EDGE_SIZE)) / EDGE_SIZE, 1)
    );
  }
  return 0;
}
