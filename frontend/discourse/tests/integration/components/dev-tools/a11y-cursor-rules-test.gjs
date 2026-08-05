import { focus } from "@ember/test-helpers";
import { module, test } from "qunit";
import * as instrumentation from "discourse/static/dev-tools/a11y/instrumentation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/**
 * Oracle for the cursor, set-position and required-attribute rules (unit 6).
 *
 * The migration underneath these rules is the risky part. Cursor classification
 * currently reads the `role` ATTRIBUTE, so it only ever sees composites and
 * items that were built by hand-writing roles. Moving it to the computed role is
 * correct and is what the rest of the panel already does, but it changes which
 * elements the rules can see, and the failure mode is silent: a widget built
 * from native elements starts reporting a defect it does not have.
 *
 * Two things make that worse than it sounds, and most of these tests exist for
 * them. `classifyCursor` prefilters candidate items with a `[role]` selector, so
 * an implicitly-roled item is not merely misjudged, it is invisible. And
 * `dom-accessibility-api` maps `td` to `cell` unconditionally, ignoring the
 * host-language rule that a `td` inside a grid is a `gridcell` — so the computed
 * role of a perfectly good grid cell is not one a grid may own.
 */
module(
  "Integration | Component | dev-tools | a11y-cursor-rules",
  function (hooks) {
    setupRenderingTest(hooks);

    let fixtures;

    hooks.beforeEach(function () {
      fixtures = [];
    });

    hooks.afterEach(function () {
      fixtures.forEach((fixture) => fixture.remove());
      instrumentation.resetA11yInstrumentation();
    });

    async function findingsAfterFocusing(html, selector = "#subject") {
      const host = document.createElement("div");
      host.innerHTML = html;
      document.body.appendChild(host);
      fixtures.push(host);

      instrumentation.attachCapture();
      await focus(host.querySelector(selector));

      return instrumentation
        .timelineEntries()
        .flatMap((entry) => entry.findings.map(({ id }) => id));
    }

    /*
     * The highest-risk case in the unit. A native grid writes no `role` on its
     * rows or cells, and the computed role of a `td` is `cell`, which is NOT an
     * item role a grid may own — `cell` is the non-interactive table variant and
     * is excluded on purpose. Left alone, every correct native grid on the page
     * reports its cursor as pointing outside its composite.
     */
    test("a native grid's cell is a legitimate cursor target", async function (assert) {
      const found = await findingsAfterFocusing(`
        <table id="subject" role="grid" aria-label="Results" tabindex="0"
               aria-activedescendant="target-cell">
          <tr><td id="target-cell">Bugs</td></tr>
        </table>
      `);

      assert.false(
        found.includes("cursor.not-item"),
        "a td in a grid is a grid cell, whatever the library computes for it"
      );
    });

    // The other half of the migration: an item carrying no `role` attribute must
    // still be found. The prefilter that selects candidates by `[role]` cannot
    // see this one at all.
    test("an implicitly-roled item is a legitimate cursor target", async function (assert) {
      const found = await findingsAfterFocusing(`
        <div id="subject" role="listbox" aria-label="Colours" tabindex="0"
             aria-activedescendant="target-option">
          <option id="target-option">Red</option>
        </div>
      `);

      assert.false(
        found.includes("cursor.not-item"),
        "an option is an option whether or not someone typed it out"
      );
    });

    // The rule still has to fire, or the two tests above are satisfied by simply
    // never reporting anything.
    test("a cursor pointing at a wrapper is still a defect", async function (assert) {
      const found = await findingsAfterFocusing(`
        <div id="subject" role="listbox" aria-label="Colours" tabindex="0"
             aria-activedescendant="target-wrapper">
          <div id="target-wrapper"><div role="option">Red</div></div>
        </div>
      `);

      assert.true(
        found.includes("cursor.not-item"),
        "readers announce the activedescendant as an item; a wrapper reads its whole subtree"
      );
    });

    test("a set position that cannot be true is a defect", async function (assert) {
      const found = await findingsAfterFocusing(`
        <div id="subject" role="listbox" aria-label="Colours" tabindex="0"
             aria-activedescendant="target-option">
          <div id="target-option" role="option" aria-posinset="0" aria-setsize="3">Red</div>
        </div>
      `);

      assert.true(
        found.includes("set.impossible"),
        "a position before the first is wrong under every reading"
      );
    });

    /*
     * These attributes exist precisely to override the DOM, and this product
     * virtualises long lists, so disagreement is usually correct rather than
     * wrong. Worth seeing when chasing "why did it say 3 of 12"; never a defect.
     */
    test("an authored set position that disagrees with the DOM is only noted", async function (assert) {
      const found = await findingsAfterFocusing(`
        <div id="subject" role="listbox" aria-label="Colours" tabindex="0"
             aria-activedescendant="target-option">
          <div id="target-option" role="option" aria-posinset="7" aria-setsize="40">Red</div>
          <div role="option">Blue</div>
        </div>
      `);

      assert.false(
        found.includes("set.impossible"),
        "seven of forty is perfectly possible"
      );
    });

    // The state IS the control. Announced without it, a checkbox tells the user
    // nothing about whether it is checked.
    test("a checkbox with no checked state is a defect", async function (assert) {
      const found = await findingsAfterFocusing(
        `<div id="subject" role="checkbox" aria-label="Watching" tabindex="0"></div>`
      );

      assert.true(found.includes("role.missing-state"));
    });

    // The host language supplies the state, so ARIA does not have to.
    test("a native checkbox supplies its own state", async function (assert) {
      const found = await findingsAfterFocusing(
        `<input id="subject" type="checkbox" aria-label="Watching" />`
      );

      assert.false(
        found.includes("role.missing-state"),
        "the element already answers the question"
      );
    });

    // ARIA defines a default, so its absence is a style question, not a defect.
    test("an attribute the spec defaults is only noted", async function (assert) {
      const found = await findingsAfterFocusing(
        `<div id="subject" role="heading" tabindex="0">Latest</div>`
      );

      assert.false(
        found.includes("role.missing-state"),
        "a heading without a level is not broken"
      );
    });

    // Zero-noise gate: correctly built widgets, native and authored, raise
    // nothing that reaches the problems filter.
    test("correctly built widgets raise nothing that ranks", async function (assert) {
      const host = document.createElement("div");
      host.innerHTML = `
        <div id="listbox" role="listbox" aria-label="Colours" tabindex="0"
             aria-activedescendant="row-a">
          <div id="row-a" role="option" aria-selected="true">Red</div>
          <div role="option" aria-selected="false">Blue</div>
        </div>
        <table id="grid" role="grid" aria-label="Results" tabindex="0"
               aria-activedescendant="cell-a">
          <tr><td id="cell-a">Bugs</td></tr>
        </table>
        <input id="check" type="checkbox" aria-label="Watching" />
      `;
      document.body.appendChild(host);
      fixtures.push(host);
      instrumentation.attachCapture();

      for (const id of ["#listbox", "#grid", "#check"]) {
        await focus(host.querySelector(id));
      }

      const ranked = instrumentation
        .timelineEntries()
        .flatMap((entry) => entry.findings)
        .filter(({ tier }) => tier === "broken");

      assert.deepEqual(
        ranked.map(({ id }) => id),
        [],
        "three correct widgets, nothing to report"
      );
    });
  }
);
