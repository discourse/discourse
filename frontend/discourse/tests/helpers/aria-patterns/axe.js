import a11yAudit from "ember-a11y-testing/test-support/audit";
import { setCustomReporter } from "ember-a11y-testing/test-support/reporter";

/**
 * axe as a recorded floor, not a gate.
 *
 * ## What this catches, and what it cannot
 *
 * axe verifies that ARIA is well-*formed*. It does not verify that it is *right*. There is no rule
 * for "this role is the wrong role" — `role="list"` where `role="listbox"` belongs passes cleanly.
 * And for the attribute this component lives and dies by, the entire idref check is:
 *
 * ```js
 * case 'idref':
 *   return !!(value && doc.getElementById(value));
 * ```
 *
 * — the target's role, its ownership by the referenced listbox, and its visibility are all
 * unchecked. So axe would NOT have caught the regression that motivated this work (a combobox that
 * opened with no cursor). Treat a pass here as "nothing is malformed", never as "the pattern is
 * satisfied"; the pattern suite in `./combobox.gjs` is what asserts that.
 *
 * ## Why a narrow gate
 *
 * A blanket `toHaveNoViolations` on a composite widget trips on rules axe gets wrong, and a gate
 * that cries wolf gets switched off. MUI's approach is followed instead: fail on a small set of
 * rules that are unambiguous for a component, and let the rest inform without blocking.
 */

/**
 * Rules disabled for composite select widgets, each with the reason it fires falsely.
 *
 * These mirror the exclusions Adobe carries for React Spectrum's own docs audit — the overlap is
 * not coincidence, it is that axe models simple widgets well and composite ones poorly.
 */
export const DISABLED_RULES = {
  // WAI-ARIA 1.2 permits `group` inside a `listbox`, which is how grouped rows are expressed.
  // axe-core has not caught up (dequelabs/axe-core#3152).
  "aria-required-children": { enabled: false },
  "aria-required-parent": { enabled: false },
  // The portaled overlay is hidden from the tree while closing, and a focusable node inside a
  // subtree mid-transition reads as a violation even though focus has already left it.
  "aria-hidden-focus": { enabled: false },
  // Page-level context, meaningless when auditing a single component root.
  region: { enabled: false },
  "page-has-heading-one": { enabled: false },
};

/**
 * Rules that genuinely should fail a build for a combobox. Deliberately short: each one is a defect
 * with no plausible false positive on this widget.
 */
export const GATED_RULES = [
  "aria-valid-attr",
  "aria-valid-attr-value",
  "aria-roles",
  "aria-required-attr",
  "aria-input-field-name",
  "aria-toggle-field-name",
  "aria-command-name",
  "aria-prohibited-attr",
  "aria-conditional-attr",
];

/**
 * Every root a combobox's markup can occupy. It is never one element.
 *
 * `class="d-combobox"` is passed to `DMenu`, which puts it on the **trigger**; the panel is a separate
 * subtree. Where that subtree lands depends on the environment: `DFloatPortal` forces inline rendering
 * under tests (`inline = args.inline ?? isTesting()`), so there is no portal outlet at all in a
 * rendering test, while a real browser teleports it into `#d-menu-portals`. Mobile uses a modal.
 *
 * Auditing the trigger alone reaches zero options and still reports clean — the state this helper
 * shipped in, caught only by mutating a row's ARIA and watching axe stay silent. Absent roots are
 * filtered out, so listing all of them is safe and keeps the helper environment-agnostic.
 */
const COMBOBOX_ROOTS = [
  ".d-combobox",
  ".fk-d-menu",
  ".fk-d-menu-modal",
  "#d-menu-portals",
];

/** Only the roots present right now; axe throws on an `include` that matches nothing. */
function presentRoots(roots) {
  return roots.filter((root) => document.querySelector(root));
}

/**
 * Audits a combobox and asserts only on {@link GATED_RULES}.
 *
 * Violations outside that set are recorded through `assert.pushResult` as passing results carrying
 * their rule ids, so a regression shows up as a reviewable diff rather than blocking the build.
 *
 * Also reports how many rows fell inside the audited scope. That number is the guard: a pass means
 * nothing if the audit never reached the options, and this helper shipped in exactly that state.
 *
 * @param {object} assert - The QUnit assert for the current test.
 * @param {string[]} [roots] - Roots to audit. Defaults to trigger plus portal, which together are
 *   the whole widget; auditing the test page instead would fold in the harness's own markup.
 */
export async function auditCombobox(assert, roots = COMBOBOX_ROOTS) {
  const include = presentRoots(Array.isArray(roots) ? roots : [roots]);

  if (!include.length) {
    assert.pushResult({
      result: false,
      actual: "none of the audit roots are in the DOM",
      expected: "at least one audit root",
      message: `axe: nothing to audit for ${JSON.stringify(roots)}`,
    });
    return;
  }

  return auditRoots(assert, include);
}

async function auditRoots(assert, include) {
  const selector = include.join(", ");
  // The default reporter throws a plain Error whose message is pre-formatted prose and which
  // carries NO structured violations, so there is nothing to triage from the catch block. Swapping
  // the reporter is the documented extension point and hands back raw axe results, which is what
  // lets a non-gated rule be recorded rather than either thrown or lost.
  let results;

  try {
    setCustomReporter((auditResults) => {
      results = auditResults;
    });
    await a11yAudit(
      { include: include.map((root) => [root]) },
      { rules: DISABLED_RULES }
    );
  } finally {
    setCustomReporter();
  }

  const violations = results?.violations ?? [];

  const gated = violations.filter((violation) =>
    GATED_RULES.includes(violation.id)
  );
  const recorded = violations.filter(
    (violation) => !GATED_RULES.includes(violation.id)
  );

  assert.pushResult({
    result: gated.length === 0,
    actual: gated.length
      ? gated.map((violation) => violation.id).join(", ")
      : "no gated violations",
    expected: "no gated violations",
    message: `axe: no violations of ${GATED_RULES.length} gated rules in ${selector}`,
  });

  // Recorded, not gated: visible in the output, never a build failure.
  assert.pushResult({
    result: true,
    actual: recorded.length
      ? recorded.map((violation) => violation.id).join(", ")
      : "none",
    expected: "recorded for review",
    message: `axe: ${recorded.length} non-gated finding(s) in ${selector}`,
  });
}

/**
 * How many listbox rows sit inside the audited roots.
 *
 * Exists so a test can prove the audit reached the widget. A scope that misses the portaled panel
 * audits zero options and still reports clean, which is how a green Tier 3 hid the fact that it was
 * only ever looking at a trigger.
 */
export function auditedOptionCount(roots = COMBOBOX_ROOTS) {
  return presentRoots(roots).reduce(
    (total, root) =>
      total + document.querySelectorAll(`${root} [role='option']`).length,
    0
  );
}
