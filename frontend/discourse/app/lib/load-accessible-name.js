import { waitForPromise } from "@ember/test-waiters";

/*
Plugins & themes are unable to async-import npm modules directly.
This wrapper provides them with a way to compute accessible names, while keeping the `import()`
in core's codebase.
*/

/**
 * Loads the accessible-name implementation and returns it with our corrections applied.
 *
 * Returns a corrected function rather than the library's raw export on purpose: importing
 * `dom-accessibility-api` directly loses the corrections below silently, and a second copy of
 * them is worse than none, because only one of the two gets fixed next time another is found.
 *
 * Serves the type-ahead wording in the WAI-ARIA Authoring Practices, which specifies moving to
 * "the next item with a NAME that starts with the typed character" — the name, not the text:
 * https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
 *
 * @returns {Promise<(element: Element) => string>} Computes the accessible name of an element,
 * per https://w3c.github.io/accname/ — what assistive technology announces for it.
 */
export default async function loadAccessibleName() {
  const { computeAccessibleName } = await waitForPromise(
    import("dom-accessibility-api")
  );

  return function accessibleName(element) {
    // `inert` is not implemented by the library, and it exposes no hook to supply one, so the
    // guard lives here: an inert subtree is out of the accessibility tree, so nothing in it has
    // a name to announce. Honest limitation — this covers an inert ROOT only. An
    // `aria-labelledby` reference reaching INTO an inert subtree is still counted, which would
    // need a fork to fix.
    if (element.closest("[inert]")) {
      return "";
    }

    // Defaults to false, which silently drops CSS `content` from every computed name. That
    // default exists for JSDOM, which logs errors for the second argument; real browsers
    // support it, and an item labelled through a pseudo-element is otherwise unmatchable.
    return computeAccessibleName(element, {
      computedStyleSupportsPseudoElements: true,
    });
  };
}
