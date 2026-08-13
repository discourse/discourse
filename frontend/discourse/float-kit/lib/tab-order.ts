/**
 * Tab-order queries for a panel that has been portaled away from its trigger.
 *
 * Sequential focus follows document order, so moving a panel out of its trigger's subtree moves
 * where Tab goes when focus leaves it: to whatever follows the portal, rather than to whatever
 * follows the control the reader is actually using. These helpers name the stop the reader
 * expected so a component can put focus there itself.
 *
 * The enumeration is only as truthful as the DOM allows. A browser with keyboard-focusable
 * scrollers adopts a scroll container as a tab stop without marking it — such an element reports
 * `tabIndex === -1` and matches no focusable selector — so it is counted by the browser and not
 * by anything here. A surface relying on these helpers has to suppress those adoptions itself
 * (an explicit `tabindex="-1"`) or its idea of "the last stop in the panel" will be wrong.
 */

/**
 * Elements that take sequential focus. Deliberately without a bare `[tabindex]`: only a
 * non-negative value is in the tab order, and `-1` is the marker for the opposite.
 */
const TAB_STOP_SELECTOR = [
  "a[href]",
  "area[href]",
  "button:not([disabled])",
  "input:not([disabled]):not([type='hidden'])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "summary",
  "iframe",
  "audio[controls]",
  "video[controls]",
  "[contenteditable]:not([contenteditable='false'])",
  "[tabindex]:not([tabindex^='-'])",
].join(", ");

/**
 * Whether `element` can actually be tabbed to right now: rendered, not hidden from the platform,
 * and not opted out. A selector alone is not enough, since a display-less or `inert` subtree
 * still matches one.
 */
function isTabbable(element: HTMLElement): boolean {
  if (element.hasAttribute("disabled") || element.tabIndex < 0) {
    return false;
  }
  if (element.closest("[inert]") || element.closest("[aria-hidden='true']")) {
    return false;
  }
  // Cheapest sufficient rendered-ness test: all three are zero only for a box that is not laid
  // out at all, which is what `display: none` (on the element or any ancestor) produces.
  return !!(
    element.offsetWidth ||
    element.offsetHeight ||
    element.getClientRects().length
  );
}

/**
 * The tab stops inside `root`, in document order. `root` itself is included when it is one, so a
 * container that has been made focusable counts as its own first stop.
 */
export function tabStopsWithin(root: HTMLElement): HTMLElement[] {
  const found = Array.from(
    root.querySelectorAll<HTMLElement>(TAB_STOP_SELECTOR)
  );
  const all = root.matches(TAB_STOP_SELECTOR) ? [root, ...found] : found;
  return all.filter(isTabbable);
}

/**
 * The document tab stop just before or just after `anchor`, ignoring anything inside `ignore`.
 *
 * `ignore` is the portaled panel: it sits somewhere else in document order, so counting its
 * controls would answer with a stop the reader is leaving rather than the one they are going to.
 *
 * Returns `null` when `anchor` is the last (or first) stop on the page, where there is nothing to
 * move to and the caller should leave focus alone.
 */
export function adjacentTabStop(
  anchor: HTMLElement,
  { forward, ignore }: { forward: boolean; ignore?: HTMLElement | null }
): HTMLElement | null {
  const stops = tabStopsWithin(document.body).filter(
    (element) => element === anchor || !ignore || !ignore.contains(element)
  );

  const index = stops.indexOf(anchor);
  if (index === -1) {
    return null;
  }

  return stops[forward ? index + 1 : index - 1] ?? null;
}
