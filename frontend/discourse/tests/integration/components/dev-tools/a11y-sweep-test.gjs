import { focus, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import * as instrumentation from "discourse/static/dev-tools/a11y/instrumentation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/**
 * Oracle for the on-demand sweep and the last of the recording defects (unit 7).
 *
 * The sweep is the feature most likely to undo everything the rest of this
 * rebuild achieved, because sweeping is how the first version produced forty
 * rows of nothing. It enumerated every control on the page and reported on each
 * one's name. So the constraints here are mostly subtractive: it looks at
 * regions and composites, it never enumerates controls for naming, it never
 * reports observations, and it says what it checked so that a clean result reads
 * as verified rather than as nothing having run.
 */
module("Integration | Component | dev-tools | a11y-sweep", function (hooks) {
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

  function sweep() {
    return instrumentation.sweepA11y?.();
  }

  test("a sweep is reachable and says what it checked", function (assert) {
    addFixture(`
      <div aria-live="polite"></div>
      <div role="listbox" aria-label="Colours"><div role="option">Red</div></div>
    `);

    const result = sweep();

    assert.true(Boolean(result), "the sweep is reachable");
    assert.strictEqual(result.regions, 1, "one region checked");
    assert.strictEqual(result.composites, 1, "one composite checked");
  });

  // A sweep that reports nothing and says nothing is indistinguishable from a
  // sweep that never ran, which is the difference between "verified" and "no
  // information".
  test("a clean page reports zero findings and a nonzero count", function (assert) {
    addFixture(`
      <div role="status" aria-live="polite"></div>
      <div role="listbox" aria-label="Colours"><div role="option">Red</div></div>
    `);

    const result = sweep();

    assert.deepEqual(result.findings, [], "nothing wrong");
    assert.true(
      result.regions + result.composites > 0,
      "and something was actually looked at"
    );
  });

  // NOTED is true-but-not-a-defect. In a timeline it is context for an event
  // that just happened; in a sweep it is a list of things nobody asked about.
  test("a sweep never reports observations", function (assert) {
    addFixture(`
      <div role="status" aria-live="polite"></div>
      <a href="#" title="Admin">Admin</a>
    `);

    const result = sweep();

    assert.deepEqual(
      result.findings.filter(({ tier }) => tier === "noted"),
      [],
      "an observation is not a sweep result"
    );
  });

  /*
   * The single most important constraint. The first version of this panel swept
   * every control on the page and reported on each one's accessible name, which
   * is how it produced a list nobody could act on. Naming is judged where focus
   * lands, not by enumeration.
   */
  test("a sweep does not enumerate controls for naming", function (assert) {
    addFixture(`
      <button></button>
      <button></button>
      <button></button>
    `);

    const result = sweep();
    const named = result.findings.filter(
      ({ id }) => id === "focus.no-name" || id.startsWith("name.")
    );

    assert.deepEqual(
      named,
      [],
      "three unnamed buttons, and not a word about it"
    );
  });

  test("a sweep aggregates by rule rather than by element", function (assert) {
    addFixture(`
      <div role="listbox" aria-label="A" aria-activedescendant="gone-a"></div>
      <div role="listbox" aria-label="B" aria-activedescendant="gone-b"></div>
      <div role="listbox" aria-label="C" aria-activedescendant="gone-c"></div>
    `);

    const result = sweep();
    const dangling = result.findings.filter(
      ({ id }) => id === "cursor.dangling"
    );

    assert.strictEqual(dangling.length, 1, "one rule, one row");
    assert.strictEqual(dangling[0].count, 3, "carrying how many hit it");
  });

  // An unopened menu is markup, not a subject. Sweeping into one reports on a
  // widget the user cannot reach and has not asked about.
  test("a sweep skips composites that are not in the tree", function (assert) {
    addFixture(`
      <div style="display: none">
        <div role="listbox" aria-label="Hidden" aria-activedescendant="gone"></div>
      </div>
    `);

    const result = sweep();

    assert.strictEqual(result.composites, 0, "nothing reachable to check");
    assert.deepEqual(result.findings, [], "and nothing reported about it");
  });

  /*
   * `keyup` fires once per physical key, so a chord ends in as many events as it
   * had keys held, and the trailing modifier release is suppressed as redundant.
   * Tracking that in a set means a chord interrupted by a blur — alt-tabbing
   * away mid-chord, which is exactly what happens when someone switches to
   * their screen reader — leaves the set holding a key that is no longer down,
   * and the NEXT press of that key is swallowed as a phantom trailing release.
   *
   * A keypress that leaves no trace cannot be told apart from capture being
   * broken, which makes this panel unable to report on its own liveness.
   */
  test("a modifier released while the page is away does not swallow the next one", async function (assert) {
    const host = addFixture(
      `<button id="subject" aria-label="Save">a</button>`
    );
    instrumentation.attachCapture();
    const subject = host.querySelector("#subject");
    await focus(subject);

    // A real chord, which is what records the modifier as still held: its own
    // release is expected next and will be suppressed as redundant.
    await triggerKeyEvent(subject, "keyup", "C", { metaKey: true });

    // The release never comes, because the page went away mid-chord.
    const before = instrumentation.timelineEntries().length;
    subject.blur();
    document.dispatchEvent(new Event("visibilitychange"));

    await triggerKeyEvent(subject, "keyup", "Meta");

    assert.true(
      instrumentation.timelineEntries().length > before,
      "the second press is a real press, not a stale release"
    );
  });

  // Two holders of the same boolean drift, and the one the panel renders is not
  // necessarily the one that gates recording.
  test("paused has a single source of truth", function (assert) {
    instrumentation.setPaused(true);

    assert.true(
      instrumentation.isPaused?.(),
      "the module reports what it was told"
    );

    instrumentation.setPaused(false);

    assert.false(instrumentation.isPaused?.(), "and reports the change");
  });
});
