import { focus, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import {
  attachCapture,
  attachLiveRegions,
  clearTimeline,
  elementHandles,
  hasElementHandle,
  installA11yTap,
  logElementHandle,
  resetA11yInstrumentation,
  TIMELINE_LIMIT,
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

  /**
   * Every path from `value` that lands on a DOM node, for the failure message.
   *
   * `Map` and `Set` have to be walked explicitly. `Object.entries` yields nothing
   * for either, so a walk built on it alone reports a clean bill of health for
   * `new Set([element])` — and the page sweep aggregates through exactly that
   * shape, `Map<string, { finding, elements: Set<Element> }>`. A strong reference
   * hidden in a collection is the same leak as a strong reference on a field.
   *
   * A `WeakRef` is a deliberate terminal: it cannot pin its target, which is the
   * whole reason it is the sanctioned way to hold onto an element here, and its
   * referent is not enumerable so the walk could not reach through it anyway.
   */
  function domNodesIn(value, path = "entry", seen = new Set()) {
    if (value === null || typeof value !== "object") {
      return [];
    }
    if (value instanceof Node) {
      return [path];
    }
    if (value instanceof WeakRef || value instanceof WeakMap) {
      return [];
    }
    if (seen.has(value)) {
      return [];
    }
    seen.add(value);

    if (value instanceof Map) {
      return [...value.entries()].flatMap(([key, nested]) => [
        ...domNodesIn(key, `${path}.<key>`, seen),
        ...domNodesIn(nested, `${path}.get(${String(key)})`, seen),
      ]);
    }
    if (value instanceof Set) {
      return [...value.values()].flatMap((nested, index) =>
        domNodesIn(nested, `${path}.<set:${index}>`, seen)
      );
    }

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

  /*
   * The walker is the instrument every assertion below depends on, so it gets
   * checked against a known leak before it is trusted with a real one. It used
   * to traverse with `Object.entries` alone, which yields nothing for a `Map` or
   * a `Set` — so an element hidden in a collection passed clean, and the page
   * sweep aggregates through exactly that shape.
   */
  test("the walker finds a node hidden in a Map or a Set", function (assert) {
    const element = document.createElement("div");

    assert.deepEqual(
      domNodesIn({ bag: new Set([element]) }),
      ["entry.bag.<set:0>"],
      "a set member is as strong a reference as a field"
    );
    assert.deepEqual(
      domNodesIn({ byRule: new Map([["cursor.dangling", element]]) }),
      ["entry.byRule.get(cursor.dangling)"],
      "and so is a map value"
    );
    assert.deepEqual(
      domNodesIn({ keyed: new Map([[element, "note"]]) }),
      ["entry.keyed.<key>"],
      "a map KEY pins its element just as hard as a value"
    );
    assert.deepEqual(
      domNodesIn({ handle: new WeakRef(element) }),
      [],
      "a weak reference cannot pin anything, which is why it is the way in"
    );
  });

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

  /*
   * Oracle for the weak handle back to the element (unit 1d).
   *
   * The panel describes an element in strings, and when that element is still on
   * the page the developer wants the node: to log it, expand it, reveal it in the
   * browser's own Elements panel. That is the ordinary devtools loop, and reading
   * "div · role=listbox · Categories" and then going hunting is the panel breaking
   * it.
   *
   * This must not undo what the rest of this file pins. A `WeakRef` cannot pin its
   * target, so the convenience comes back without the leak — but only while two
   * things hold: the handles live outside the entries, and no handle ever feeds
   * displayed data. Everything a row SAYS stays frozen at record time.
   *
   * These tests live here rather than in their own file because the walker above
   * is the instrument that tells a weak handle from a strong one, and because the
   * running devserver expands its test-discovery glob only at a full build, so a
   * new file reports "No tests matched" instead of running.
   */
  module("weak element handles (unit 1d)", function () {
    test("a described element is reachable as a handle to the node itself", async function (assert) {
      await captureDanglingCursor();

      const { seq } = eventEntry();
      assert.true(
        hasElementHandle(seq, "focused"),
        "the focused element was described, so it has a handle"
      );

      const logged = sinon.stub(console, "log");
      try {
        assert.true(
          logElementHandle(seq, "focused"),
          "activating the control resolves the node"
        );
        assert.strictEqual(
          logged.firstCall.args.at(-1),
          document.querySelector("#leak-fixture"),
          "and logs that exact node, which is what gives an expandable handle"
        );
      } finally {
        logged.restore();
      }
    });

    // The fallback is the thing that was always there: no handle, no control, and
    // nothing said about why. A field the snapshot never filled has no node behind
    // it, and that is not a failure to report.
    test("a field that described nothing has no handle", async function (assert) {
      await captureDanglingCursor();

      const { seq, snapshot } = eventEntry();
      assert.strictEqual(
        snapshot.cursorTarget,
        undefined,
        "the cursor dangles, so no target was described"
      );
      assert.false(
        hasElementHandle(seq, "cursorTarget"),
        "so there is nothing to offer a control for"
      );
    });

    /*
     * A handle hangs off the identity line, so a node with no identity line has
     * nowhere to put one. `body` is deliberately left undescribed, and it is the
     * common case: it holds focus whenever nothing else does.
     */
    test("a present node the panel does not describe gets no handle", async function (assert) {
      attachCapture();
      document.body.click();
      await settled();

      const entry = timelineEntries().find((one) => one.label === "click");
      assert.strictEqual(
        entry.snapshot.focused,
        undefined,
        "body is present and deliberately not described"
      );
      assert.false(
        hasElementHandle(entry.seq, "focused"),
        "so there is no control to offer"
      );
    });

    /*
     * The test a strong implementation fails. A `Map<seq, Element>` would satisfy
     * every other assertion here — handles resolve, pruning works — while pinning
     * exactly what this file exists to keep unpinned, because the registry sits
     * outside the entries the other walks cover.
     */
    test("the registry holds weak handles and never a node", async function (assert) {
      await captureDanglingCursor();

      assert.deepEqual(
        domNodesIn(elementHandles(), "handles"),
        [],
        "a node found here is a strong reference wearing a handle's name"
      );
      assert.true(
        elementHandles().every((handle) => handle instanceof WeakRef),
        "and the only sanctioned way to hold an element is the one that cannot pin it"
      );
    });

    // A node the page has finished with still derefs, and the console showing it
    // detached is where that belongs. Garbage-collection timing carries no
    // information about the page, so the panel says nothing about it either.
    test("a detached element still resolves while it is alive", async function (assert) {
      await captureDanglingCursor();

      const { seq } = eventEntry();
      const element = document.querySelector("#leak-fixture");
      element.remove();

      const logged = sinon.stub(console, "log");
      try {
        assert.true(logElementHandle(seq, "focused"), "detached is not gone");
        assert.strictEqual(logged.firstCall.args.at(-1), element);
      } finally {
        logged.restore();
      }
    });

    // A handle whose entry the ring has dropped is unreachable, so keeping its
    // record would grow the registry for the life of the session — the same
    // unbounded growth this file exists to prevent, one indirection further out.
    test("handles are released with the entry they belong to", async function (assert) {
      await captureDanglingCursor();

      const { seq } = eventEntry();
      assert.true(
        hasElementHandle(seq, "focused"),
        "held while the entry lives"
      );

      clearTimeline();

      assert.false(
        hasElementHandle(seq, "focused"),
        "clearing the timeline releases what nothing can reach"
      );
      assert.deepEqual(elementHandles(), [], "and leaves no record behind");
    });

    /*
     * The path that actually matters, because a long session never clears: the
     * ring drops its oldest entry on every new one, so a registry that only
     * pruned on Clear would grow for as long as the panel is recording.
     */
    test("handles are released when the ring evicts their entry", async function (assert) {
      installA11yTap();
      await captureDanglingCursor();

      const { seq } = eventEntry();
      assert.true(
        hasElementHandle(seq, "focused"),
        "held while the entry lives"
      );

      for (let i = 0; i < TIMELINE_LIMIT; i++) {
        this.a11y.announce(`m${i}`, "polite");
      }
      await settled();

      assert.strictEqual(
        eventEntry(),
        undefined,
        "the event has been pushed out of the ring"
      );
      assert.false(
        hasElementHandle(seq, "focused"),
        "and its handle went with it"
      );
    });
  });
});
