import { computeAccessibleName } from "dom-accessibility-api";

/** Composite container roles and the item roles their cursor may target. */
export const COMPOSITE_ROLES: Record<string, readonly string[]> = {
  listbox: ["option"],
  menu: ["menuitem", "menuitemcheckbox", "menuitemradio"],
  menubar: ["menuitem", "menuitemcheckbox", "menuitemradio"],
  tree: ["treeitem"],
  grid: ["row", "gridcell", "rowheader", "columnheader"],
  treegrid: ["row", "gridcell", "rowheader", "columnheader"],
  tablist: ["tab"],
  radiogroup: ["radio"],
};

export type CursorState = "absent" | "dangling" | "not_item" | "ok";

export interface CursorInfo {
  state: CursorState;
  target: Element | null;
  container: Element | null;
  index?: number;
}

export type Containment =
  | { kind: "none" }
  | { kind: "descendant" }
  | { kind: "claimed"; via: string[] }
  | { kind: "unclaimed" };

function compositeContainer(target: Element): Element | null {
  let ancestor = target.parentElement;

  while (ancestor) {
    const role = ancestor.getAttribute("role");
    if (role && COMPOSITE_ROLES[role]) {
      return ancestor;
    }
    ancestor = ancestor.parentElement;
  }

  return null;
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

  const container = compositeContainer(target);
  const containerRole = container?.getAttribute("role");
  const itemRoles = containerRole ? COMPOSITE_ROLES[containerRole] : undefined;
  const targetRole = target.getAttribute("role");

  if (
    !container ||
    !itemRoles ||
    !targetRole ||
    !itemRoles.includes(targetRole)
  ) {
    return { state: "not_item", target, container };
  }

  const items = Array.from(container.querySelectorAll("[role]")).filter(
    (item) => itemRoles.includes(item.getAttribute("role") ?? "")
  );

  return {
    state: "ok",
    target,
    container,
    index: items.indexOf(target),
  };
}

/** Lists accessibility-tree barriers from the element outward, nearest first. */
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
    if (node.hasAttribute("popover")) {
      barriers.push("popover");
    }
    if (node.getAttribute("aria-modal") === "true") {
      barriers.push("aria-modal");
    }

    const role = node.getAttribute("role");
    if (role === "dialog" || role === "alertdialog") {
      barriers.push(`role=${role}`);
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

/** Composes the relevant screen-reader utterance for an element. */
export function composeUtterance(element: Element): string {
  const utterance = [computeAccessibleName(element)];
  const position = element.getAttribute("aria-posinset");
  const size = element.getAttribute("aria-setsize");

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
