import { computeAccessibleName } from "dom-accessibility-api";

/**
 * Composes what a screen reader would say when the cursor lands on a listbox row.
 *
 * Attribute assertions and accessibility-tree snapshots both miss a whole class of defect, because
 * each individual attribute can be correct while the *composed phrase* misleads. The open example is
 * a row that announces "Watching, 4 of 6" one press away from "6 of 6": `aria-posinset` and
 * `aria-setsize` are each exactly what the engine intended, and the utterance is still wrong, because
 * a row the cursor cannot reach consumed a position.
 *
 * Nothing else in the suite can express that. `assert.combobox().hasContiguousPositions()` checks the
 * attributes across every rendered row; the system-spec aria snapshot does not serialize position at
 * all (Playwright emits only `url, checked, disabled, expanded, invalid, level, pressed, selected`);
 * and the live-region log sees only announcements, never rows.
 *
 * The accessible name comes from `dom-accessibility-api` — the implementation behind Testing Library's
 * `getByRole` — rather than `textContent`, because a row's name can come from `aria-label`,
 * `aria-labelledby`, or a subtree with presentational children, and reading text would silently
 * disagree with what is actually announced.
 *
 * Phrasing here is ours and is deliberately not anybody's real screen reader. Assert on structure —
 * which rows speak, in what order, with which positions — never on an exact string.
 */

/** A row the keyboard cursor can actually land on. Disabled rows are read but not reachable. */
function isNavigable(option) {
  return option.getAttribute("aria-disabled") !== "true";
}

/**
 * The spoken form of one option: name, position in set, then any state a reader would hear.
 *
 * @param {Element} option - An element with `role="option"`.
 * @returns {string} e.g. `"Watching, 4 of 6, selected"`.
 */
export function composeOptionUtterance(option) {
  const parts = [computeAccessibleName(option)];

  const posinset = option.getAttribute("aria-posinset");
  const setsize = option.getAttribute("aria-setsize");

  if (posinset && setsize) {
    // A source still paging reports an indeterminate size rather than lying with the mounted count,
    // and a reader hears that as no position at all rather than as "of -1".
    parts.push(setsize === "-1" ? `${posinset}` : `${posinset} of ${setsize}`);
  }

  if (option.getAttribute("aria-selected") === "true") {
    parts.push("selected");
  }

  if (option.getAttribute("aria-disabled") === "true") {
    parts.push("unavailable");
  }

  return parts.filter(Boolean).join(", ");
}

/**
 * Every rendered row's utterance, in DOM order.
 *
 * @param {object} [options]
 * @param {boolean} [options.navigableOnly] - Drop rows the cursor cannot land on. This is the
 *   distinction the "4 of 6" defect turns on: including unreachable rows makes the positions look
 *   contiguous, which is why an attribute check over all rows does not catch it.
 */
export function optionUtterances({ navigableOnly = false } = {}) {
  const listbox = document.querySelector("[role='listbox']");
  const options = [...(listbox?.querySelectorAll("[role='option']") ?? [])];

  return options
    .filter((option) => !navigableOnly || isNavigable(option))
    .map(composeOptionUtterance);
}

/**
 * The positions a reader would hear while stepping through the reachable rows.
 *
 * Parsed back out of the composed utterance rather than read off the attributes, so the assertion is
 * about what gets said. A gap here is a row that speaks a position the cursor can never land on.
 */
export function navigablePositions() {
  return optionUtterances({ navigableOnly: true }).map((phrase) => {
    const match = phrase.match(/(\d+) of \d+/);
    return match ? Number(match[1]) : null;
  });
}
