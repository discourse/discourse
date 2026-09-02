/** The axes a strip can scroll on. A strip is measured one axis at a time. */
export type ScrollAxis = "horizontal" | "vertical";

/** Which axes a container can scroll on, as read from its computed overflow. */
export type ScrollableAxes = Record<ScrollAxis, boolean>;

/** Where a scroll container's content sits relative to its viewport on one axis. */
export interface ScrollEdgeState {
  /** The content is larger than the container on this axis. */
  overflowing: boolean;
  /** The container rests on its start edge. */
  atStart: boolean;
  /** The container rests on its end edge. */
  atEnd: boolean;
}

/**
 * One measurement of both axes. An axis is `null` when the container's
 * computed overflow does not let it scroll there, so geometric overflow
 * behind `overflow: hidden` never counts as scrollable.
 */
export interface ScrollEdgesSnapshot {
  /** The horizontal axis, or `null` when the container cannot scroll on it. */
  horizontal: ScrollEdgeState | null;
  /** The vertical axis, or `null` when the container cannot scroll on it. */
  vertical: ScrollEdgeState | null;
  /** The axis whose state is stamped on the element, if any axis can scroll. */
  primary: ScrollAxis | null;
}

/**
 * Slack in pixels: an offset this close to an edge counts as resting on it,
 * and content that outgrows the viewport by no more than this does not
 * count as overflowing.
 */
const EDGE_TOLERANCE = 2;

function isScrollable(overflow: string) {
  return overflow === "auto" || overflow === "scroll";
}

/** Reads which axes the container's computed overflow lets it scroll on. */
function scrollableAxes(element: HTMLElement): ScrollableAxes {
  const { overflowX, overflowY } = getComputedStyle(element);
  return {
    horizontal: isScrollable(overflowX),
    vertical: isScrollable(overflowY),
  };
}

/**
 * Measures one axis. Offsets are read as magnitudes, so a right-to-left
 * container reports the same logical edges as a left-to-right one.
 */
function measureScrollEdges(
  element: HTMLElement,
  axis: ScrollAxis
): ScrollEdgeState {
  const horizontal = axis === "horizontal";
  const viewport = horizontal ? element.clientWidth : element.clientHeight;
  const content = horizontal ? element.scrollWidth : element.scrollHeight;
  const offset = Math.abs(horizontal ? element.scrollLeft : element.scrollTop);
  const overflowing = content - viewport > EDGE_TOLERANCE;

  return {
    overflowing,
    atStart: overflowing && offset <= EDGE_TOLERANCE,
    atEnd: overflowing && content - offset - viewport <= EDGE_TOLERANCE,
  };
}

/**
 * Writes the primary axis's state onto the element as data attributes, so
 * a stylesheet can react to it: `data-d-scroll-axis` names the axis, and
 * `data-d-scroll-overflow`, `data-d-scroll-at-start`, `data-d-scroll-at-end`
 * are present while true.
 */
function stampScrollEdges(element: HTMLElement, snapshot: ScrollEdgesSnapshot) {
  const { primary } = snapshot;
  const state = primary ? snapshot[primary] : null;

  if (primary) {
    element.setAttribute("data-d-scroll-axis", primary);
  } else {
    element.removeAttribute("data-d-scroll-axis");
  }
  element.toggleAttribute("data-d-scroll-overflow", !!state?.overflowing);
  element.toggleAttribute("data-d-scroll-at-start", !!state?.atStart);
  element.toggleAttribute("data-d-scroll-at-end", !!state?.atEnd);
}

/**
 * Measures every scrollable axis. An explicit axis reports only itself. In
 * `"auto"`, the primary axis is the first scrollable axis that overflows,
 * horizontal before vertical, else the first scrollable axis.
 */
function snapshotScrollEdges(
  element: HTMLElement,
  axis: ScrollAxis | "auto",
  scrollable: ScrollableAxes = scrollableAxes(element)
): ScrollEdgesSnapshot {
  const measure = (candidate: ScrollAxis) =>
    scrollable[candidate] ? measureScrollEdges(element, candidate) : null;

  if (axis !== "auto") {
    const state = measure(axis);
    return {
      horizontal: axis === "horizontal" ? state : null,
      vertical: axis === "vertical" ? state : null,
      primary: axis,
    };
  }

  const horizontal = measure("horizontal");
  const vertical = measure("vertical");
  let primary: ScrollAxis | null = null;
  if (horizontal?.overflowing) {
    primary = "horizontal";
  } else if (vertical?.overflowing) {
    primary = "vertical";
  } else if (horizontal) {
    primary = "horizontal";
  } else if (vertical) {
    primary = "vertical";
  }

  return { horizontal, vertical, primary };
}

function sameState(a: ScrollEdgeState | null, b: ScrollEdgeState | null) {
  if (a === null || b === null) {
    return a === b;
  }
  return (
    a.overflowing === b.overflowing &&
    a.atStart === b.atStart &&
    a.atEnd === b.atEnd
  );
}

function sameSnapshot(a: ScrollEdgesSnapshot, b: ScrollEdgesSnapshot) {
  return (
    a.primary === b.primary &&
    sameState(a.horizontal, b.horizontal) &&
    sameState(a.vertical, b.vertical)
  );
}

/**
 * Keeps a scroll container's edge state current and stamped on it.
 *
 * Scrolling only re-measures against cached scrollability. Resizes and
 * child changes also re-read it, which lets an axis flip at a breakpoint.
 * Child sizes are observed directly, which catches a late web font swap.
 *
 * `onChange` fires only when the snapshot differs.
 */
export class ScrollEdgesWatcher {
  /** Re-reads scrollability and re-measures. */
  refresh = () => {
    this.#scrollable = scrollableAxes(this.#element);
    this.#measure();
  };
  #element: HTMLElement;
  #axis: ScrollAxis | "auto";
  #onChange: ((snapshot: ScrollEdgesSnapshot) => void) | undefined;
  #resizeObserver: ResizeObserver;
  #mutationObserver: MutationObserver;
  #scrollable: ScrollableAxes | null = null;
  #last: ScrollEdgesSnapshot | null = null;

  #measure = () => {
    const scrollable = this.#scrollable ?? scrollableAxes(this.#element);
    const snapshot = snapshotScrollEdges(this.#element, this.#axis, scrollable);
    if (this.#last && sameSnapshot(this.#last, snapshot)) {
      return;
    }
    this.#last = snapshot;
    stampScrollEdges(this.#element, snapshot);
    this.#onChange?.(snapshot);
  };

  #observeSizes = () => {
    this.#resizeObserver.disconnect();
    this.#resizeObserver.observe(this.#element);
    for (const child of this.#element.children) {
      this.#resizeObserver.observe(child);
    }
    this.refresh();
  };

  constructor(
    element: HTMLElement,
    options: {
      axis: ScrollAxis | "auto";
      onChange?: (snapshot: ScrollEdgesSnapshot) => void;
    }
  ) {
    this.#element = element;
    this.#axis = options.axis;
    this.#onChange = options.onChange;
    this.#resizeObserver = new ResizeObserver(this.refresh);
    this.#mutationObserver = new MutationObserver(this.#observeSizes);

    element.addEventListener("scroll", this.#measure, { passive: true });
    this.#mutationObserver.observe(element, { childList: true });
    this.#observeSizes();
  }

  disconnect() {
    this.#resizeObserver.disconnect();
    this.#mutationObserver.disconnect();
    this.#element.removeEventListener("scroll", this.#measure);
  }
}
