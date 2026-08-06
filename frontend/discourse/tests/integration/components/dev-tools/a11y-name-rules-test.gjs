import { focus } from "@ember/test-helpers";
import { module, test } from "qunit";
import * as instrumentation from "discourse/static/dev-tools/a11y/instrumentation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/**
 * Oracle for the focus and naming rules (unit 4).
 *
 * This is the half of the catalogue most likely to turn the panel back into
 * noise, because almost every naming pattern that looks wrong is in fact how
 * the product is built. An icon button named by its `title`, a link whose
 * `title` repeats its own text — these are everywhere, they are not defects,
 * and the previous version of this panel flagged all of them. So the tests
 * below spend more effort on what must stay quiet than on what must fire.
 *
 * Only two things here are genuinely broken: focus landing somewhere the reader
 * cannot follow, and a control whose role is meaningless without a name having
 * none. Everything else is an observation.
 */
module(
  "Integration | Component | dev-tools | a11y-name-rules",
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

    function addFixture(html) {
      const host = document.createElement("div");
      host.innerHTML = html;
      document.body.appendChild(host);
      fixtures.push(host);

      return host;
    }

    /** Focus the fixture's subject and return what the capture concluded. */
    async function findingsAfterFocusing(html, selector = "#subject") {
      const host = addFixture(html);
      instrumentation.attachCapture();
      await focus(host.querySelector(selector));

      return instrumentation
        .timelineEntries()
        .flatMap((entry) => entry.findings.map(({ id }) => id));
    }

    // The reader follows the accessibility tree, not the focus ring. Focus that
    // lands outside the tree leaves the user with no way to know where they are.
    test("focus landing outside the accessibility tree is a defect", async function (assert) {
      const found = await findingsAfterFocusing(
        `<div aria-hidden="true"><button id="subject">Save</button></div>`
      );

      assert.true(found.includes("focus.not-in-tree"));
    });

    test("a control whose role needs a name and has none is a defect", async function (assert) {
      const found = await findingsAfterFocusing(
        `<button id="subject"></button>`
      );

      assert.true(
        found.includes("focus.no-name"),
        "the reader announces the role and nothing else"
      );
    });

    test("a control whose role does not need a name is not a defect", async function (assert) {
      const found = await findingsAfterFocusing(
        `<div id="subject" tabindex="0"></div>`
      );

      assert.false(
        found.includes("focus.no-name"),
        "an unnamed generic element is not a control missing its name"
      );
    });

    test("a named control raises nothing at all", async function (assert) {
      const found = await findingsAfterFocusing(
        `<button id="subject">Save draft</button>`
      );

      assert.deepEqual(found, [], "the ordinary case is silent");
    });

    // An author who wrote both meant them to be read as two different things.
    // NVDA and JAWS read the description after the name at default verbosity, so
    // the user hears the same words twice.
    test("a description that merely repeats the name is fragile", async function (assert) {
      const found = await findingsAfterFocusing(`
      <button id="subject" aria-label="Save" aria-describedby="subject-hint"></button>
      <span id="subject-hint">Save</span>
    `);

      assert.true(found.includes("name.describedby-echoes-name"));
    });

    // `title` is the last resort in the name computation and several mobile
    // assistive technologies never surface it. Worth knowing, not worth ranking:
    // it is how most icon-only controls in the product are named.
    test("a name that came only from title is noted, never ranked", async function (assert) {
      const found = await findingsAfterFocusing(
        `<button id="subject" title="Save draft"></button>`
      );

      assert.true(found.includes("name.from-title-only"));
      assert.false(
        found.includes("focus.no-name"),
        "it does have a name, just a fragile source for one"
      );
      /*
       * The library will lie to you here, and the rule has to not believe it.
       * `computeAccessibleDescription` falls back to `title` unconditionally,
       * even when the name was computed FROM that same title — its source
       * carries a TODO saying exactly that. So the raw description equals the
       * name, which looks like a title duplicating a name and is not: a reader
       * announces this button's title once, as its name.
       */
      assert.false(
        found.includes("name.title-duplicates-name"),
        "one title used once is not a duplicate"
      );
    });

    /*
     * The exact pattern that made the first version of this panel useless. Every
     * link in the sidebar looks like this, none of them is broken, and a filter
     * that ranks them ranks nothing.
     */
    test("a title repeating a link's own text is noted, never ranked", async function (assert) {
      const found = await findingsAfterFocusing(
        `<a id="subject" href="#" title="Admin">Admin</a>`
      );

      assert.false(
        found.includes("name.describedby-echoes-name"),
        "an implicit description from title is not an authored contradiction"
      );
      assert.false(
        found.includes("focus.no-name"),
        "it is named, and named well"
      );
      // Here the title really is a second source: the name came from the link's
      // own text, and the title repeats it. A reader says it twice.
      assert.true(
        found.includes("name.title-duplicates-name"),
        "named by its text, described by a title saying the same thing"
      );
      assert.false(
        found.includes("name.from-title-only"),
        "the name did not come from the title"
      );
    });

    // User agents ignore an unmatched idref and compose the name from the tokens
    // that do resolve, so a partly-broken reference usually still names the
    // control. Worth seeing when chasing a wrong announcement; not a defect.
    test("a labelledby with one dead reference is noted, not broken", async function (assert) {
      const found = await findingsAfterFocusing(`
      <button id="subject" aria-labelledby="subject-word subject-missing"></button>
      <span id="subject-word">Save</span>
    `);

      assert.false(
        found.includes("focus.no-name"),
        "the surviving token still names it"
      );
    });

    // The one that decides whether a dead reference matters: when nothing
    // resolves, the control really is unnamed, and that is the broken rule's job.
    test("a labelledby that resolves to nothing is a control with no name", async function (assert) {
      const found = await findingsAfterFocusing(
        `<button id="subject" aria-labelledby="subject-missing"></button>`
      );

      assert.true(
        found.includes("focus.no-name"),
        "an unresolvable label leaves the reader with the role alone"
      );
    });

    // Zero-noise gate for this half: a page of ordinary, correctly built controls
    // must produce nothing that reaches the problems filter.
    test("ordinary controls raise nothing that ranks", async function (assert) {
      const host = addFixture(`
      <a id="link" href="#" title="Admin">Admin</a>
      <button id="icon" title="Reply"></button>
      <input id="field" type="text" aria-label="Search" />
      <button id="plain">Save draft</button>
    `);
      instrumentation.attachCapture();

      for (const id of ["#link", "#icon", "#field", "#plain"]) {
        await focus(host.querySelector(id));
      }

      const ranked = instrumentation
        .timelineEntries()
        .flatMap((entry) => entry.findings)
        .filter(({ tier }) => tier === "broken");

      assert.deepEqual(
        ranked.map(({ id }) => id),
        [],
        "four correct controls, nothing to report"
      );
    });
  }
);
