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

    /*
     * Unit 0a — the contract/convention split.
     *
     * A composite's visual "active" row is only evidence of a defect when
     * something owns both it and `aria-activedescendant`. Where the marker is a
     * styling convention nobody enforces, divergence is routine: the marker may
     * sit on a wrapper, `aria-current` means the current PAGE, and `.--active`
     * is generic. Reporting those as broken is the false positive this whole
     * catalogue exists to remove.
     *
     * So an owner declares the contract by stamping `data-active-descendant` on
     * the row it considers active. The attribute — not a class name — is the
     * signal, because a roving-focus owner's active class is caller-supplied and
     * therefore has no stable name core could ever match on.
     */
    const CONTRACT = "data-active-descendant";

    function composite({ cursor, marker, markerAttrs }) {
      return `
        <div id="subject" role="listbox" tabindex="0"
             aria-label="Categories" aria-activedescendant="${cursor}">
          <div id="opt-1" role="option" ${marker === "opt-1" ? markerAttrs : ""}>Bugs</div>
          <div id="opt-2" role="option" ${marker === "opt-2" ? markerAttrs : ""}>Features</div>
        </div>
      `;
    }

    test("divergence under the contract is broken", async function (assert) {
      const found = await findingsAfterFocusing(
        composite({ cursor: "opt-1", marker: "opt-2", markerAttrs: CONTRACT })
      );

      assert.true(
        found.includes("cursor.visual-diverged"),
        "an owner of both the marker and the cursor disagreeing with itself is a defect"
      );
      assert.false(
        found.includes("cursor.visual-diverged-conventional"),
        "the contract case must not also report the conventional rule"
      );
    });

    test("divergence under a convention is noted, not broken", async function (assert) {
      const found = await findingsAfterFocusing(
        composite({
          cursor: "opt-1",
          marker: "opt-2",
          markerAttrs: `class="--active"`,
        })
      );

      assert.true(
        found.includes("cursor.visual-diverged-conventional"),
        "worth seeing, since nothing enforces a styling marker"
      );
      assert.false(
        found.includes("cursor.visual-diverged"),
        "this is the false positive the split exists to remove"
      );
    });

    test("agreement reports nothing, under either signal", async function (assert) {
      const contract = await findingsAfterFocusing(
        composite({ cursor: "opt-2", marker: "opt-2", markerAttrs: CONTRACT })
      );
      const convention = await findingsAfterFocusing(
        composite({
          cursor: "opt-2",
          marker: "opt-2",
          markerAttrs: `class="--active"`,
        })
      );

      assert.deepEqual(
        [contract, convention].map((found) =>
          found.filter((id) => id.startsWith("cursor.visual-diverged"))
        ),
        [[], []],
        "the marker and the cursor are the same row in both"
      );
    });

    /*
     * The precedence case, and the reason it is not merely tidiness: a composite
     * under contract routinely carries conventional markers too, because the
     * same row is usually styled with an `--active` class. Reading the
     * convention first would classify a genuine contract breach as NOTED and
     * bury it.
     */
    test("the contract marker wins when both signals are present", async function (assert) {
      const found = await findingsAfterFocusing(`
        <div id="subject" role="listbox" tabindex="0"
             aria-label="Categories" aria-activedescendant="opt-1">
          <div id="opt-1" role="option" ${CONTRACT}>Bugs</div>
          <div id="opt-2" role="option" class="--active">Features</div>
        </div>
      `);

      assert.deepEqual(
        found.filter((id) => id.startsWith("cursor.visual-diverged")),
        [],
        "the contract agrees with the cursor, so a stray styling class decides nothing"
      );
    });

    /*
     * The inverse of the case above, and the more dangerous direction. Reading
     * the conventional marker first would find agreement here and report
     * nothing at all, silently swallowing a genuine contract breach — a
     * failure the previous test cannot detect, because there the wrong answer
     * is noisy rather than silent.
     */
    test("a contract breach is reported even when a conventional marker agrees", async function (assert) {
      const found = await findingsAfterFocusing(`
        <div id="subject" role="listbox" tabindex="0"
             aria-label="Categories" aria-activedescendant="opt-1">
          <div id="opt-1" role="option" class="--active">Bugs</div>
          <div id="opt-2" role="option" ${CONTRACT}>Features</div>
        </div>
      `);

      assert.true(
        found.includes("cursor.visual-diverged"),
        "the owner's own marker is on a different row from its own cursor"
      );
    });

    /*
     * The conventional selector carries three alternatives and only one of them
     * was exercised, so dropping either of the others would not have shown up.
     * `aria-current` is the one worth spelling out: it is routinely present and
     * `false` on every row but one, which is why the selector filters it.
     */
    test("every conventional marker is recognised", async function (assert) {
      const markers = [
        `class="--active"`,
        `data-active`,
        `aria-current="true"`,
      ];
      const results = [];

      for (const marker of markers) {
        // The timeline is module-scoped and only cleared between tests, so
        // without this each pass reports its predecessors' findings too.
        instrumentation.resetA11yInstrumentation();

        results.push(
          await findingsAfterFocusing(`
            <div id="subject" role="listbox" tabindex="0"
                 aria-label="Categories" aria-activedescendant="opt-1">
              <div id="opt-1" role="option" aria-current="false">Bugs</div>
              <div id="opt-2" role="option" ${marker}>Features</div>
            </div>
          `)
        );
      }

      assert.deepEqual(
        results.map((found) =>
          found.filter((id) => id.startsWith("cursor.visual-diverged"))
        ),
        markers.map(() => ["cursor.visual-diverged-conventional"]),
        "all three styling markers diverge, and none of them is a defect"
      );
    });

    test("a composite with no marker at all reports neither", async function (assert) {
      const found = await findingsAfterFocusing(`
        <div id="subject" role="listbox" tabindex="0"
             aria-label="Categories" aria-activedescendant="opt-1">
          <div id="opt-1" role="option">Bugs</div>
          <div id="opt-2" role="option">Features</div>
        </div>
      `);

      assert.deepEqual(
        found.filter((id) => id.startsWith("cursor.visual-diverged")),
        [],
        "no visual cursor means no comparison, not a failed one"
      );
    });

    /*
     * The sweep is a second, independent emit site. It classified divergence on
     * its own before this split and will keep doing so unless it is changed
     * with the per-event path.
     */
    function sweptFindings(html) {
      const host = document.createElement("div");
      host.innerHTML = html;
      document.body.appendChild(host);
      fixtures.push(host);

      return instrumentation.sweepA11y().findings.map(({ id }) => id);
    }

    test("the sweep reports a contract breach", async function (assert) {
      const found = sweptFindings(`
        <div role="listbox" aria-label="Contract" aria-activedescendant="c-1">
          <div id="c-1" role="option">Bugs</div>
          <div id="c-2" role="option" ${CONTRACT}>Features</div>
        </div>
      `);

      assert.true(
        found.includes("cursor.visual-diverged"),
        "an owner disagreeing with itself is exactly what a page scan is for"
      );
    });

    /*
     * The half that has to be asserted alone. Swept together with a contract
     * breach, both composites produce the same rule id, so a run that reports
     * conventional divergence as broken is indistinguishable from a correct one.
     */
    test("the sweep is silent on a conventional divergence", async function (assert) {
      const found = sweptFindings(`
        <div role="listbox" aria-label="Convention" aria-activedescendant="v-1">
          <div id="v-1" role="option">Bugs</div>
          <div id="v-2" role="option" class="--active">Features</div>
        </div>
      `);

      assert.deepEqual(
        found.filter((id) => id.startsWith("cursor.visual-diverged")),
        [],
        "NOTED never enters a sweep, and this is not broken"
      );
    });
  }
);
