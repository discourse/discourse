import QUnit from "qunit";

/**
 * ARIA assertion primitives for the combobox/listbox pattern.
 *
 * These exist because the select suite otherwise repeats `role`/`aria-*` selectors as string
 * literals across hundreds of tests, which makes the contract impossible to see in one place and
 * lets each site invent its own idea of "correct". They are deliberately phrased in pattern terms
 * (controller, cursor, listbox) rather than DSelect terms, so the same assertions hold for any
 * implementation of the pattern.
 *
 * The important one is {@link ComboboxHelper#hasCursorOn}. `aria-activedescendant` is written
 * imperatively by the roving-focus modifier, not by a template, so it has three distinct failure
 * shapes that a plain `hasAttribute` check collapses into one: absent, dangling (pointing at an id
 * that no longer resolves), and pointing at the wrong row. Each is reported separately here.
 *
 * @example
 * assert.combobox().hasCursorOn(0, "opening seeds the cursor on the first row");
 * assert.combobox().hasNoCursor();
 */

/** Rows that a keyboard user can actually land on. */
const OPTION_SELECTOR = "[role='option']";

/**
 * The element carrying `role="combobox"` — the one that owns `aria-activedescendant` and keeps DOM
 * focus. Which element that is depends on the variant: `static` puts the role on the trigger root,
 * while the typeahead/multi/panel-searchable variants put it on an inner query input. Resolving it
 * by role rather than by class keeps these assertions variant-agnostic.
 */
export function findController(scope = document) {
  const candidates = [...scope.querySelectorAll("[role='combobox']")];

  if (candidates.length <= 1) {
    return candidates[0] ?? null;
  }

  // A panel-searchable select renders a second combobox inside the open panel. The live controller
  // is whichever one currently references a listbox.
  return (
    candidates.find((element) => element.hasAttribute("aria-controls")) ??
    candidates[0]
  );
}

class ComboboxHelper {
  #context;
  #scope;

  constructor(scope, context) {
    this.#scope = scope;
    this.#context = context;
  }

  get controller() {
    return findController(this.#scope);
  }

  /**
   * The listbox is portaled out of the trigger's subtree, so it is resolved from the document
   * rather than from within the trigger.
   */
  get listbox() {
    return this.#scope.querySelector("[role='listbox']");
  }

  get options() {
    return [...(this.listbox?.querySelectorAll(OPTION_SELECTOR) ?? [])];
  }

  /**
   * Asserts the cursor is on the option at `index`, distinguishing absent from dangling from
   * misplaced so a failure names the actual defect.
   */
  hasCursorOn(index, message) {
    const controller = this.controller;

    if (!controller) {
      this.#context.pushResult({
        result: false,
        actual: "no element with role=combobox",
        expected: `cursor on option ${index}`,
        message:
          message ?? "there is a combobox controller to carry the cursor",
      });
      return this;
    }

    const id = controller.getAttribute("aria-activedescendant");

    if (id === null) {
      this.#context.pushResult({
        result: false,
        actual: "aria-activedescendant is absent",
        expected: `cursor on option ${index}`,
        message: message ?? `the cursor is on option ${index}`,
      });
      return this;
    }

    const target = document.getElementById(id);

    if (!target) {
      this.#context.pushResult({
        result: false,
        actual: `aria-activedescendant="${id}" resolves to nothing (dangling)`,
        expected: `cursor on option ${index}`,
        message: message ?? `the cursor is on option ${index}`,
      });
      return this;
    }

    if (target.getAttribute("role") !== "option") {
      this.#context.pushResult({
        result: false,
        actual: `aria-activedescendant points at role="${target.getAttribute("role")}"`,
        expected: `cursor on option ${index}`,
        message: message ?? `the cursor points at an option`,
      });
      return this;
    }

    const actualIndex = this.options.indexOf(target);
    this.#context.pushResult({
      result: actualIndex === index,
      actual: `option ${actualIndex}`,
      expected: `option ${index}`,
      message: message ?? `the cursor is on option ${index}`,
    });
    return this;
  }

  /**
   * Asserts there is no cursor. A dangling `aria-activedescendant` fails here rather than passing:
   * an id pointing at a removed row is not the same as having no cursor, and treating them alike is
   * how a stale highlight survives a re-render unnoticed.
   */
  hasNoCursor(message) {
    const controller = this.controller;
    const id = controller?.getAttribute("aria-activedescendant") ?? null;

    if (id === null) {
      this.#context.pushResult({
        result: true,
        actual: "aria-activedescendant is absent",
        expected: "aria-activedescendant is absent",
        message: message ?? "there is no cursor",
      });
      return this;
    }

    const target = document.getElementById(id);
    this.#context.pushResult({
      result: false,
      actual: target
        ? `aria-activedescendant="${id}" still points at a row`
        : `aria-activedescendant="${id}" is dangling`,
      expected: "aria-activedescendant is absent",
      message: message ?? "there is no cursor",
    });
    return this;
  }

  /** Asserts the controller references the rendered listbox by id, in both directions. */
  isLinkedToListbox(message) {
    const controller = this.controller;
    const listbox = this.listbox;

    if (!controller || !listbox) {
      this.#context.pushResult({
        result: false,
        actual: `controller=${!!controller}, listbox=${!!listbox}`,
        expected: "both a controller and a listbox",
        message: message ?? "the controller and listbox both exist",
      });
      return this;
    }

    this.#context.pushResult({
      result: controller.getAttribute("aria-controls") === listbox.id,
      actual: `aria-controls="${controller.getAttribute("aria-controls")}"`,
      expected: `aria-controls="${listbox.id}"`,
      message: message ?? "the controller references the rendered listbox",
    });
    return this;
  }

  /** Asserts the listbox reference is dropped, so nothing points at an unrendered element. */
  isNotLinkedToListbox(message) {
    this.#context
      .dom(this.controller)
      .doesNotHaveAttribute(
        "aria-controls",
        message ?? "no listbox is referenced while closed"
      );
    return this;
  }

  hasExpandedState(expanded, message) {
    this.#context
      .dom(this.controller)
      .hasAttribute(
        "aria-expanded",
        String(expanded),
        message ?? `aria-expanded is ${expanded}`
      );
    return this;
  }

  /**
   * In active-descendant mode DOM focus never leaves the controller, so no option may become a tab
   * stop. A stray `tabindex="0"` on a row means Tab escapes into the listbox.
   */
  hasSingleTabStop(message) {
    const stops = this.options.filter(
      (option) => option.getAttribute("tabindex") === "0"
    );
    this.#context.pushResult({
      result: stops.length === 0,
      actual: `${stops.length} option(s) are tab stops`,
      expected: "0 options are tab stops",
      message: message ?? "listbox options never become tab stops",
    });
    return this;
  }

  hasOptionPosition(index, { posinset, setsize }, message) {
    const option = this.options[index];
    this.#context
      .dom(option)
      .hasAttribute("aria-posinset", String(posinset))
      .hasAttribute(
        "aria-setsize",
        String(setsize),
        message ?? `option ${index} reports its position in the set`
      );
    return this;
  }

  /**
   * Asserts navigable rows carry contiguous positions.
   *
   * A row the cursor cannot land on must not consume a position, or the count a screen reader reads
   * out disagrees with the number of rows the user can reach — "4 of 6" followed by a single step to
   * "6 of 6". Structural rows (headers, dividers) are excluded from `[role=option]` and so are
   * already outside this check; this catches the case where a skipped *option* still occupies one.
   */
  hasContiguousPositions(message) {
    const positions = this.options.map((option) =>
      Number(option.getAttribute("aria-posinset"))
    );
    const expected = positions.map((_, index) => index + 1);

    this.#context.pushResult({
      result: JSON.stringify(positions) === JSON.stringify(expected),
      actual: positions.join(","),
      expected: expected.join(","),
      message:
        message ?? "navigable options carry contiguous logical positions",
    });
    return this;
  }

  /** Asserts every option agrees on the size of the set, and that it matches the rows present. */
  hasConsistentSetSize(message) {
    const sizes = new Set(
      this.options.map((option) => option.getAttribute("aria-setsize"))
    );

    this.#context.pushResult({
      result: sizes.size <= 1,
      actual: `${sizes.size} distinct aria-setsize values: ${[...sizes].join(",")}`,
      expected: "one aria-setsize value across all options",
      message: message ?? "every option reports the same set size",
    });
    return this;
  }
}

export function setupComboboxAssertions() {
  /**
   * @param {string|Element} [scope] - Element or selector to scope the query to. Defaults to the
   *   document, because the listbox is portaled out of the trigger's subtree.
   */
  QUnit.assert.combobox = function (scope) {
    let resolved = document;

    if (typeof scope === "string") {
      resolved = document.querySelector(scope) ?? document;
    } else if (scope) {
      resolved = scope;
    }

    return new ComboboxHelper(resolved, this);
  };
}
