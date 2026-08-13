/**
 * Tab-order queries for a panel that has been portaled away from its trigger.
 *
 * Sequential focus follows document order, so moving a panel out of its trigger's subtree moves
 * where Tab goes when focus leaves it: to whatever follows the portal, rather than to whatever
 * follows the control the reader is actually using. These helpers name the stop the reader
 * expected so a component can put focus there itself.
 *
 * The enumeration is only as truthful as the DOM allows. A browser with keyboard-focusable
 * scrollers adopts a scroll container as a tab stop without marking it, while iframe and shadow
 * focus scopes do not expose their internal key events or stops here. A surface relying on these
 * helpers must avoid those focus scopes and suppress adopted scrollers with `tabindex="-1"`.
 */

/** Elements that can take sequential focus when their current state permits it. */
const TAB_STOP_SELECTOR = [
  "a[href]",
  "area[href]",
  "button",
  "input:not([type='hidden'])",
  "select",
  "textarea",
  "summary",
  "iframe",
  "audio[controls]",
  "video[controls]",
  "[contenteditable]:not([contenteditable='false'])",
  "[tabindex]",
].join(", ");

interface TabStopsOptions {
  ignore?: HTMLElement | null;
}

function isIgnored(element: HTMLElement, ignore?: HTMLElement | null) {
  return Boolean(ignore && (element === ignore || ignore.contains(element)));
}

/** Whether `element` can actually be reached by sequential focus right now. */
function isTabbable(element: HTMLElement): boolean {
  if (element.tabIndex < 0 || element.matches(":disabled")) {
    return false;
  }
  if (element.closest("[inert]")) {
    return false;
  }

  const visibility = getComputedStyle(element).visibility;
  if (visibility === "hidden" || visibility === "collapse") {
    return false;
  }

  return Boolean(
    element.offsetWidth ||
    element.offsetHeight ||
    element.getClientRects().length
  );
}

function radioGroupRepresentative(
  radio: HTMLInputElement,
  ignore?: HTMLElement | null
): HTMLInputElement | null {
  if (!radio.name) {
    return radio;
  }

  const tree = radio.getRootNode();
  if (!(tree instanceof Document || tree instanceof ShadowRoot)) {
    return radio;
  }

  const members = Array.from(
    tree.querySelectorAll<HTMLInputElement>("input[type='radio']")
  ).filter(
    (member) =>
      member.name === radio.name &&
      member.form === radio.form &&
      !isIgnored(member, ignore) &&
      isTabbable(member)
  );

  return members.find((member) => member.checked) ?? members[0] ?? null;
}

function isRadio(element: HTMLElement): element is HTMLInputElement {
  return (
    element instanceof HTMLInputElement &&
    element.type.toLowerCase() === "radio"
  );
}

function compareTabOrder(
  left: { element: HTMLElement; documentIndex: number },
  right: { element: HTMLElement; documentIndex: number }
) {
  const leftPositive = left.element.tabIndex > 0;
  const rightPositive = right.element.tabIndex > 0;

  if (leftPositive !== rightPositive) {
    return leftPositive ? -1 : 1;
  }
  if (leftPositive && left.element.tabIndex !== right.element.tabIndex) {
    return left.element.tabIndex - right.element.tabIndex;
  }
  return left.documentIndex - right.documentIndex;
}

/**
 * The tab stops inside `root`, in a native-like local sequence. `root` itself is included when it
 * is a stop. Positive tabindex values are ordered within this local segment; portaling cannot
 * reproduce their global position without changing the surrounding page's tab order as well.
 */
export function tabStopsWithin(
  root: HTMLElement,
  { ignore }: TabStopsOptions = {}
): HTMLElement[] {
  const found = Array.from(
    root.querySelectorAll<HTMLElement>(TAB_STOP_SELECTOR)
  );
  const all = root.matches(TAB_STOP_SELECTOR) ? [root, ...found] : found;

  return all
    .filter(
      (element) =>
        !isIgnored(element, ignore) &&
        isTabbable(element) &&
        (!isRadio(element) ||
          radioGroupRepresentative(element, ignore) === element)
    )
    .map((element, documentIndex) => ({ element, documentIndex }))
    .sort(compareTabOrder)
    .map(({ element }) => element);
}

function isBefore(left: HTMLElement, right: HTMLElement) {
  const position = left.compareDocumentPosition(right);
  return (
    position === Node.DOCUMENT_POSITION_FOLLOWING ||
    position ===
      Node.DOCUMENT_POSITION_FOLLOWING + Node.DOCUMENT_POSITION_CONTAINED_BY
  );
}

/**
 * The local tab stop just before or after `anchor`.
 *
 * By default the search covers the page. `root` narrows it to a panel, and `ignore` excludes a
 * portaled panel while finding the page stop beside its trigger. When programmatic focus rests on
 * a non-candidate, DOM position determines the next candidate in the requested direction.
 */
export function adjacentTabStop(
  anchor: HTMLElement,
  {
    forward,
    ignore,
    root = document.body,
  }: {
    forward: boolean;
    ignore?: HTMLElement | null;
    root?: HTMLElement;
  }
): HTMLElement | null {
  let stops = tabStopsWithin(root, { ignore });
  const index = stops.indexOf(anchor);

  if (index !== -1) {
    return stops[forward ? index + 1 : index - 1] ?? null;
  }

  if (isRadio(anchor)) {
    const representative = radioGroupRepresentative(anchor, ignore);
    // Script can focus another member of an unchecked group, but Tab leaves the group from there
    // instead of visiting the representative that sequential entry would use.
    if (representative && !representative.checked) {
      stops = stops.filter((stop) => stop !== representative);
    }
  }

  const candidates = stops.filter((stop) =>
    forward ? isBefore(anchor, stop) : isBefore(stop, anchor)
  );

  return (forward ? candidates[0] : candidates.at(-1)) ?? null;
}
