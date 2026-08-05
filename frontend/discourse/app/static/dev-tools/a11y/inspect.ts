import {
  computeAccessibleDescription,
  computeAccessibleName,
  getRole,
  isInaccessible,
} from "dom-accessibility-api";
import {
  isComposite,
  itemRolesFor,
} from "discourse/static/dev-tools/a11y/aria";
import { type A11yPass, beginPass } from "discourse/static/dev-tools/a11y/dom";

export type CursorState = "absent" | "dangling" | "not_item" | "ok";

export interface CursorInfo {
  state: CursorState;
  target: Element | null;
  container: Element | null;
  index?: number;
  size?: number;
}

/** `unknown` covers a missing half, which is never reported as agreement. */
export type CursorAgreement = "unknown" | "agree" | "diverged";

/**
 * Markers a composite conventionally puts on the row the eye follows. Nothing
 * enforces them, so a composite marking its cursor another way yields no visual
 * cursor rather than the wrong one. `aria-current` is routinely present and
 * `false` on every row but one, hence the filter.
 */
export const VISUAL_CURSOR_SELECTOR =
  "[data-active], .--active, [aria-current]:not([aria-current='false'])";

/** Ember names most elements, and the name says nothing about the element. */
const GENERATED_ID = /^ember\d+$/;
const NAME_LIMIT = 40;

/** Tags whose name already conveys their role, so printing it adds nothing. */
const ROLE_IS_OBVIOUS = new Set([
  "a",
  "button",
  "form",
  "img",
  "input",
  "select",
  "textarea",
]);

export type Containment =
  | { kind: "none" }
  | { kind: "descendant" }
  | { kind: "claimed"; via: string[] }
  | { kind: "unclaimed" };

function identify(element: Element): string | undefined {
  const name = computeAccessibleName(element).trim();
  if (name) {
    return name.length > NAME_LIMIT ? `${name.slice(0, NAME_LIMIT)}…` : name;
  }

  const className = element.className?.toString().trim().split(/\s+/)[0];
  if (className) {
    return className;
  }

  return element.id && !GENERATED_ID.test(element.id) ? element.id : undefined;
}

/**
 * A readable identity for an element: tag, then role, then a name. Deliberately
 * not id-first — Ember generates an id for most elements, so an id-first
 * description reads `ember143` and discards what identifies the control.
 *
 * The role is the COMPUTED one, which is what the accessibility tree sees and
 * may differ from the attribute. It is omitted where the tag already implies it,
 * so a sidebar of anchors does not repeat `role=link` on every row.
 */
export function describeElement(element: Element | null): string | undefined {
  if (!element || element === element.ownerDocument.body) {
    return undefined;
  }

  const tag = element.tagName.toLowerCase();
  const parts = [tag];
  const role = getRole(element);
  if (
    role &&
    role !== "generic" &&
    (element.hasAttribute("role") || !ROLE_IS_OBVIOUS.has(tag))
  ) {
    parts.push(`role=${role}`);
  }

  const name = identify(element);
  if (name) {
    parts.push(name);
  }

  return parts.join(" · ");
}

/**
 * Whether the accessibility tree excludes the element outright.
 *
 * Complements the barrier walk rather than repeating it: this also accounts for
 * `display: none` and `visibility: hidden`, which no attribute inspection can
 * see, and answers yes/no where the barrier list only enumerates suspects.
 */
export function hiddenFromReader(element: Element | null): boolean {
  return Boolean(element) && isInaccessible(element!);
}

export function visualCursor(container: Element | null): Element | null {
  return container?.querySelector(VISUAL_CURSOR_SELECTOR) ?? null;
}

/**
 * Compares the two cursors a composite maintains. They are separate state, and
 * where they drift apart no attribute inspected alone reveals it.
 */
export function compareCursors(
  target: Element | null,
  visual: Element | null
): CursorAgreement {
  if (!target || !visual) {
    return "unknown";
  }

  return target === visual ? "agree" : "diverged";
}

function compositeContainer(target: Element, pass: A11yPass): Element | null {
  let ancestor = target.parentElement;

  while (ancestor) {
    const role = pass.role(ancestor);
    if (role && isComposite(role)) {
      return ancestor;
    }
    ancestor = ancestor.parentElement;
  }

  return null;
}

function cursorItemRole(
  role: string | undefined,
  containerRole: string
): string {
  // dom-accessibility-api always maps td to cell and does not implement the
  // host-language rule that makes a td inside a grid a gridcell.
  if (
    role === "cell" &&
    (containerRole === "grid" || containerRole === "treegrid")
  ) {
    return "gridcell";
  }

  return role ?? "";
}

/** Classifies the focused element's active-descendant cursor. */
export function classifyCursor(focused: Element | null): CursorInfo {
  const activeId = focused?.getAttribute("aria-activedescendant");
  if (activeId === null || activeId === undefined) {
    return { state: "absent", target: null, container: null };
  }

  const target = focused.ownerDocument.getElementById(activeId);
  if (!target) {
    return { state: "dangling", target: null, container: null };
  }

  const pass = beginPass();
  const container = compositeContainer(target, pass);
  const containerRole = container ? pass.role(container) : undefined;
  const itemRoles = containerRole ? itemRolesFor(containerRole) : undefined;
  const targetRole = containerRole
    ? cursorItemRole(pass.role(target), containerRole)
    : "";

  if (!container || !itemRoles?.has(targetRole)) {
    return { state: "not_item", target, container };
  }

  const items = Array.from(container.querySelectorAll("*")).filter((item) =>
    itemRoles.has(cursorItemRole(pass.role(item), containerRole))
  );

  return {
    state: "ok",
    target,
    container,
    index: items.indexOf(target),
    size: items.length,
  };
}

/**
 * What on the path out of the element removes it from the accessibility tree,
 * nearest first. Explains a `hiddenFromReader` verdict rather than standing in
 * for one.
 *
 * Only `inert` and `aria-hidden` qualify. A `role="dialog"` ancestor, an
 * `aria-modal`, or a popover is how a modal is built: each makes the rest of
 * the page unreachable while the element inside stays perfectly readable, so
 * reporting them here flagged every control in every dialog.
 */
export function describeBarriers(element: Element): string[] {
  const barriers: string[] = [];
  let node: Element | null = element;

  while (node) {
    if (node.hasAttribute("inert")) {
      barriers.push("inert");
    }
    if (node.getAttribute("aria-hidden") === "true") {
      barriers.push("aria-hidden");
    }

    node = node.parentElement;
  }

  return barriers;
}

function referencesTarget(
  focused: Element,
  attribute: "aria-owns" | "aria-controls",
  target: Element
): boolean {
  const ids =
    focused.getAttribute(attribute)?.split(/\s+/).filter(Boolean) ?? [];

  return ids.some((id) =>
    focused.ownerDocument.getElementById(id)?.contains(target)
  );
}

/** Describes the DOM or ARIA relationship between focused and target elements. */
export function describeContainment(
  focused: Element | null,
  target: Element | null
): Containment {
  if (!target) {
    return { kind: "none" };
  }
  if (focused?.contains(target)) {
    return { kind: "descendant" };
  }
  if (!focused) {
    return { kind: "unclaimed" };
  }

  const via = (["aria-owns", "aria-controls"] as const).filter((attribute) =>
    referencesTarget(focused, attribute, target)
  );

  return via.length ? { kind: "claimed", via } : { kind: "unclaimed" };
}

/**
 * Composes the relevant screen-reader utterance for an element. Name, then
 * description, then state — the order readers announce them in.
 */
export function composeUtterance(element: Element): string {
  const utterance = [computeAccessibleName(element)];
  const description = accessibleDescription(element);
  const position = element.getAttribute("aria-posinset");
  const size = element.getAttribute("aria-setsize");

  if (description) {
    utterance.push(description);
  }
  if (position !== null && size !== null) {
    utterance.push(`${position} of ${size}`);
  }
  if (element.getAttribute("aria-selected") === "true") {
    utterance.push("selected");
  }
  if (element.getAttribute("aria-disabled") === "true") {
    utterance.push("disabled");
  }

  return utterance.join(", ");
}

/**
 * The description a reader would add after the name, if it adds anything.
 *
 * A description equal to the name is dropped. Usually the title WAS the name
 * and the library reported it in both roles: an icon-only anchor whose children
 * are all `aria-hidden` is named by its title, and a reader says that title
 * once. Deciding otherwise means re-deriving which source the name came from,
 * and the obvious proxies are wrong — `textContent` counts `aria-hidden`
 * subtrees, so it sees content where the accessibility tree sees none.
 *
 * The residue is a title duplicating an `aria-label`, which really is read
 * twice and is dropped here too. That is deliberate: it is a minor, common nit,
 * and reporting it is not worth flagging every icon button in the product.
 */
export function accessibleDescription(element: Element): string {
  const description = computeAccessibleDescription(element).trim();

  return description && description !== computeAccessibleName(element).trim()
    ? description
    : "";
}
