import { focus, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import {
  attachCapture,
  attachLiveRegions,
  resetA11yInstrumentation,
  timelineEntries,
  watchedLiveRegions,
} from "discourse/static/dev-tools/a11y/instrumentation";
import A11yPanel from "discourse/static/dev-tools/a11y/panel";
import { clearDockPanels, closeDock } from "discourse/static/dev-tools/dock";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/**
 * Oracle for the recording leak (unit 2).
 *
 * The timeline keeps 200 entries and outlives the panel by design, so whatever
 * an entry holds is held for the whole session. Today an entry holds four or
 * five live DOM nodes, which pins their entire detached subtrees: a session
 * spent opening and closing modals accumulates thousands of nodes the page has
 * otherwise finished with.
 *
 * Fixing that is not only a memory question. Once an entry stops holding nodes
 * it also stops being able to re-derive anything at render, which is the second
 * claim here: what a row says is decided when the row is recorded. A panel that
 * re-reads the DOM to decide whether an old event was a problem is reporting on
 * the page as it is now, under a sequence number from a minute ago.
 *
 * Fixtures are built with plain DOM rather than templates on purpose. These
 * tests remove nodes mid-test, and removing a node Glimmer owns makes teardown
 * throw `removeChild` — which aborts the whole run rather than failing a test.
 */
module("Integration | Component | dev-tools | a11y-leak", function (hooks) {
  setupRenderingTest(hooks);

  let fixtures;

  hooks.beforeEach(function () {
    fixtures = [];
    this.a11y = this.owner.lookup("service:a11y");
    disableClearA11yAnnouncementsInTests();
  });

  hooks.afterEach(function () {
    fixtures.forEach((fixture) => fixture.remove());
    resetA11yInstrumentation();
    closeDock();
    clearDockPanels();
    enableClearA11yAnnouncementsInTests();
  });

  // On the body, not the render root: a re-render replaces the root's contents,
  // and a fixture that vanishes with it cannot tell "still there" from "gone".
  function addFixture(html) {
    const host = document.createElement("div");
    host.innerHTML = html;
    document.body.appendChild(host);
    fixtures.push(host);

    return host;
  }

  /** Every path from `value` that lands on a DOM node, for the failure message. */
  function domNodesIn(value, path = "entry", seen = new Set()) {
    if (value === null || typeof value !== "object") {
      return [];
    }
    if (value instanceof Node) {
      return [path];
    }
    if (seen.has(value)) {
      return [];
    }
    seen.add(value);

    return Object.entries(value).flatMap(([key, nested]) =>
      domNodesIn(nested, `${path}.${key}`, seen)
    );
  }

  /**
   * A composite whose cursor points at nothing, so a finding is produced.
   *
   * The element is handed to `focus` rather than a selector: the test helpers
   * resolve selectors against the render root, and these fixtures deliberately
   * sit outside it.
   */
  async function captureDanglingCursor() {
    const host = addFixture(`
      <div
        id="leak-fixture"
        role="listbox"
        tabindex="0"
        aria-activedescendant="leak-missing-row"
      ><div id="leak-row" role="option">a row</div></div>
    `);

    attachCapture();
    await focus(host.querySelector("#leak-fixture"));
  }

  function eventEntry() {
    return timelineEntries().find((entry) => entry.kind === "event");
  }

  test("no timeline entry holds a DOM node", async function (assert) {
    await captureDanglingCursor();

    const entries = timelineEntries();
    assert.true(entries.length > 0, "something was recorded to inspect");

    for (const entry of entries) {
      assert.deepEqual(
        domNodesIn(entry),
        [],
        `entry #${entry.seq} (${entry.label}) holds no DOM node`
      );
    }
  });

  test("an entry still describes what it saw after the DOM is gone", async function (assert) {
    await captureDanglingCursor();

    const before = timelineEntries().map((entry) => entry.detail);
    assert.true(before.length > 0, "something was recorded");

    document.querySelector("#leak-fixture").remove();
    await settled();

    assert.deepEqual(
      timelineEntries().map((entry) => entry.detail),
      before,
      "the trace is a record, not a live query"
    );
  });

  // The panel reads these off the entry. Derived at render instead, a row that
  // said "problem" a minute ago silently stops saying it the moment the page
  // moves on, and the count beside the filter drifts with the DOM.
  test("an event entry carries its findings, decided when it was recorded", async function (assert) {
    await captureDanglingCursor();

    const event = eventEntry();
    assert.true(Boolean(event), "an event was captured");
    assert.true(Array.isArray(event.findings), "findings are on the entry");
    assert.true(
      event.findings.some(({ id }) => id === "cursor.dangling"),
      "a cursor pointing at a missing id is recorded as such"
    );
    assert.true(Object.isFrozen(event.findings), "and cannot be edited later");
  });

  test("repairing the page does not retract a finding already recorded", async function (assert) {
    await captureDanglingCursor();

    const event = eventEntry();
    assert.true(
      event.findings.some(({ id }) => id === "cursor.dangling"),
      "recorded while the cursor was dangling"
    );

    // The id now resolves. The event being described still happened.
    document.querySelector("#leak-row").id = "leak-missing-row";
    await settled();

    assert.true(
      event.findings.some(({ id }) => id === "cursor.dangling"),
      "the recorded event is unchanged"
    );
  });

  test("a region that leaves the DOM is released when the panel goes away", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    addFixture(`<div id="leak-region" aria-live="polite"></div>`);
    attachLiveRegions();

    assert.true(
      watchedLiveRegions().some((name) => name.includes("leak-region")),
      "watched to begin with"
    );

    document.querySelector("#leak-region").remove();
    await render(<template></template>);

    assert.false(
      watchedLiveRegions().some((name) => name.includes("leak-region")),
      "closing the panel is the last chance to notice it left"
    );
  });

  /*
   * A test lived here pinning that every registered rule rendered SOMETHING,
   * because the panel held a hand-written map of ids to English and any rule
   * missing from it displayed the word "undefined" as a problem row.
   *
   * That map is gone. Rules are translated through `findingKey`, and the
   * guarantee is now stronger and checked where it belongs: `a11y-panel-i18n`
   * asserts every registered id resolves to a real string rather than a
   * missing-key marker. Keeping this version would pin the shim rather than the
   * property it stood in for.
   */

  // The dock is opened and closed repeatedly across a session, and each open
  // attaches observers. If closing does not release them, the observer list
  // grows without bound over an afternoon's debugging — and because a stale
  // observer still fires, the panel starts reporting deliveries into regions
  // that no longer exist.
  test("opening and closing the dock repeatedly returns to baseline", async function (assert) {
    await render(<template><A11yLiveRegions /></template>);
    attachLiveRegions();

    const baseline = watchedLiveRegions().length;
    assert.true(baseline > 0, "something is watched to begin with");

    for (let cycle = 0; cycle < 5; cycle++) {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );
      attachLiveRegions();

      await render(<template><A11yLiveRegions /></template>);
    }

    // Re-attach before counting. Each cycle replaces the regions, so straight
    // after a close the watched set is legitimately empty — the regions it held
    // really did leave. The property under test is that cycling does not
    // ACCUMULATE, which is only visible once watching resumes.
    attachLiveRegions();

    assert.strictEqual(
      watchedLiveRegions().length,
      baseline,
      "five open/close cycles later, the same count and no more"
    );
  });

  // Recording outlives the panel on purpose: the workflow is to close it,
  // reproduce on an unobstructed page, then reopen and read the trace. Pruning
  // must therefore release what has gone and nothing else.
  test("a region still in the DOM survives the panel going away", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    addFixture(`<div id="leak-region" aria-live="polite"></div>`);
    attachLiveRegions();

    assert.true(
      watchedLiveRegions().some((name) => name.includes("leak-region")),
      "watched to begin with"
    );

    await render(<template></template>);

    assert.true(
      watchedLiveRegions().some((name) => name.includes("leak-region")),
      "still watching a region that is still there"
    );
  });
});
