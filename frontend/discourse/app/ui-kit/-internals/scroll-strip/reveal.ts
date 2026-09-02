/** How a revealed element is placed inside the scroll container. */
export interface RevealOptions {
  /**
   * `"nearest"` moves the container the least distance that brings the
   * element fully inside, clear of any scroll padding. `"center"` centres
   * it. Defaults to `"nearest"`.
   */
  align?: "nearest" | "center";
}

/**
 * An element's layout position, summed up its offsetParent chain. Layout
 * offsets ignore CSS transforms, which bounding rects do not, and a scroll
 * position is a layout quantity.
 */
export function layoutOffset(element: HTMLElement) {
  let x = 0;
  let y = 0;
  let node: HTMLElement | null = element;
  while (node) {
    x += node.offsetLeft;
    y += node.offsetTop;
    node = node.offsetParent instanceof HTMLElement ? node.offsetParent : null;
  }
  return { x, y };
}

/**
 * A computed scroll-padding side in pixels. A percentage stays a percentage
 * in the computed style, so it is resolved here against the scrollport.
 */
function padding(value: string, scrollport: number) {
  const parsed = Number.parseFloat(value);
  if (!Number.isFinite(parsed)) {
    return 0;
  }
  return value.trim().endsWith("%") ? (parsed / 100) * scrollport : parsed;
}

function nearest(
  start: number,
  end: number,
  padStart: number,
  padEnd: number,
  offset: number,
  viewport: number
) {
  if (start - padStart < offset) {
    return start - padStart;
  }
  if (end + padEnd > offset + viewport) {
    return end + padEnd - viewport;
  }
  return offset;
}

/**
 * Scrolls `scroller`, never the page, until `target` lies inside it. Scroll
 * padding is honoured by hand since it ignores programmatic scrolls. The
 * write is left unclamped: the browser clamps it, RTL's negative range
 * included.
 */
export function revealInScroller(
  scroller: HTMLElement,
  target: HTMLElement,
  { align = "nearest" }: RevealOptions = {}
) {
  const origin = layoutOffset(scroller);
  const position = layoutOffset(target);
  const start = { x: position.x - origin.x, y: position.y - origin.y };
  const end = {
    x: start.x + target.offsetWidth,
    y: start.y + target.offsetHeight,
  };

  let left: number;
  let top: number;
  if (align === "center") {
    left = start.x + target.offsetWidth / 2 - scroller.clientWidth / 2;
    top = start.y + target.offsetHeight / 2 - scroller.clientHeight / 2;
  } else {
    const style = getComputedStyle(scroller);
    left = nearest(
      start.x,
      end.x,
      padding(style.scrollPaddingLeft, scroller.clientWidth),
      padding(style.scrollPaddingRight, scroller.clientWidth),
      scroller.scrollLeft,
      scroller.clientWidth
    );
    top = nearest(
      start.y,
      end.y,
      padding(style.scrollPaddingTop, scroller.clientHeight),
      padding(style.scrollPaddingBottom, scroller.clientHeight),
      scroller.scrollTop,
      scroller.clientHeight
    );
  }

  if (left === scroller.scrollLeft && top === scroller.scrollTop) {
    return;
  }

  scroller.scrollTo({ left, top, behavior: "instant" });
}
