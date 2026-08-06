/**
 * Centralizes accessibility reads into a pass because each pass is a snapshot:
 * findings are recorded once, then rendered much later from a timeline that
 * outlives the DOM they describe.
 *
 * The accessibility library defaults `computedStyleSupportsPseudoElements` to
 * false, which silently drops CSS `content` from every computed name. It also
 * does not implement `inert`, so this boundary preserves CSS-generated names
 * and adds inert-subtree handling for every caller.
 */
import {
  computeAccessibleDescription,
  computeAccessibleName,
  getRole,
  isInaccessible,
  isSubtreeInaccessible,
} from "dom-accessibility-api";

export interface A11yPass {
  name(element: Element): string;
  description(element: Element): string;
  role(element: Element): string | undefined;
  hidden(element: Element): boolean;
}

function cached<T>(compute: (element: Element) => T): (element: Element) => T {
  const values = new WeakMap<Element, { value: T }>();

  return (element) => {
    const cachedValue = values.get(element);
    if (cachedValue) {
      return cachedValue.value;
    }

    const value = compute(element);
    values.set(element, { value });
    return value;
  };
}

export function beginPass(): A11yPass {
  const subtreeHidden = cached(
    (element) => element.hasAttribute("inert") || isSubtreeInaccessible(element)
  );

  return {
    name: cached((element) =>
      computeAccessibleName(element, {
        computedStyleSupportsPseudoElements: true,
      })
    ),
    description: cached((element) =>
      computeAccessibleDescription(element, {
        computedStyleSupportsPseudoElements: true,
      })
    ),
    role: cached((element) => getRole(element) ?? undefined),
    hidden: cached((element) =>
      isInaccessible(element, { isSubtreeInaccessible: subtreeHidden })
    ),
  };
}
