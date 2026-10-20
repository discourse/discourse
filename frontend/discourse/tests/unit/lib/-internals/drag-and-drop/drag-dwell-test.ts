import { destroy } from "@ember/destroyable";
import { resetOnerror, settled, setupOnerror } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { createDragDwell } from "discourse/ui-kit/modifiers/d-drag-dwell";

/* Under test, discourseLater collapses every delay to a 10ms runloop timer
   (app/lib/later.ts), so `await settled()` resolves a pending dwell and the
   configured delay value itself is unobservable. The fake-clock tests below
   tick around that collapsed 10ms deadline and stay fully synchronous: a
   restored fake clock orphans any still-pending backburner timer, so each of
   them must end with the dwell fired or reset. */

module("Unit | Lib | drag-dwell", function (hooks) {
  setupTest(hooks);

  let parent: object;

  hooks.beforeEach(function () {
    parent = {};
  });

  hooks.afterEach(function () {
    // Quiesces any timer a failing test left behind, via the registered
    // destructor, before the test-isolation validator looks for one.
    destroy(parent);
  });

  test("fires with the target once the delay elapses, never synchronously", async function (assert) {
    const seen: string[] = [];
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      onDwell: (target: string) => seen.push(target),
    });

    dwell.update("candidate");
    assert.deepEqual(seen, [], "nothing fires synchronously");

    await settled();
    assert.deepEqual(seen, ["candidate"], "fires once the delay elapses");
  });

  test("omitting delay uses the built-in default", function (assert) {
    const clock = sinon.useFakeTimers({
      now: Date.now(),
      shouldAdvanceTime: false,
    });

    try {
      const seen: string[] = [];
      const dwell = createDragDwell({
        destroyable: parent,
        onDwell: (target: string) => seen.push(target),
      });

      dwell.update("candidate");
      clock.tick(5);
      // An unapplied default would pass `undefined` to the scheduler, which
      // skips the numeric test-time collapse and misses the 10ms deadline.
      assert.deepEqual(seen, [], "not fired before the collapsed deadline");

      clock.tick(6);
      assert.deepEqual(seen, ["candidate"], "fired at the collapsed deadline");
    } finally {
      clock.restore();
    }
  });

  test("does not re-fire while the same identity continues uninterrupted", async function (assert) {
    const seen: string[] = [];
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      onDwell: (target: string) => seen.push(target),
    });

    dwell.update("candidate");
    await settled();
    assert.deepEqual(seen, ["candidate"], "fired once");

    dwell.update("candidate");
    dwell.update("candidate");
    await settled();
    assert.deepEqual(
      seen,
      ["candidate"],
      "continued same-identity reports never re-fire"
    );
  });

  test("a same-identity report does not push the deadline back", function (assert) {
    const clock = sinon.useFakeTimers({
      now: Date.now(),
      shouldAdvanceTime: false,
    });

    try {
      const seen: string[] = [];
      const dwell = createDragDwell({
        destroyable: parent,
        delay: 300,
        onDwell: (target: string) => seen.push(target),
      });

      dwell.update("candidate");
      clock.tick(6);
      dwell.update("candidate");
      clock.tick(6);

      // 12ms is past the collapsed 10ms deadline; an implementation that
      // restarted the timer on the second report would need 16ms.
      assert.deepEqual(seen, ["candidate"], "the original deadline held");
    } finally {
      clock.restore();
    }
  });

  test("an identity change cancels the pending dwell and arms a full fresh delay", function (assert) {
    const clock = sinon.useFakeTimers({
      now: Date.now(),
      shouldAdvanceTime: false,
    });

    try {
      const seen: object[] = [];
      const first = { label: "same shape" };
      const second = { label: "same shape" };
      const dwell = createDragDwell({
        destroyable: parent,
        delay: 300,
        onDwell: (target: object) => seen.push(target),
      });

      dwell.update(first);
      clock.tick(6);
      // Structurally equal but a different reference: a NEW identity under
      // the default identity function.
      dwell.update(second);
      clock.tick(6);
      assert.deepEqual(
        seen,
        [],
        "12ms in, the restarted deadline has not elapsed"
      );

      clock.tick(5);
      assert.strictEqual(seen.length, 1, "fires once the fresh delay elapses");
      assert.strictEqual(seen[0], second, "fires with the new target only");
    } finally {
      clock.restore();
    }
  });

  test("a null report cancels the pending dwell, and repeated nulls are no-ops", async function (assert) {
    const seen: string[] = [];
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      onDwell: (target: string) => seen.push(target),
    });

    dwell.update(null);
    dwell.update(null);

    dwell.update("candidate");
    await settled();
    assert.deepEqual(
      seen,
      ["candidate"],
      "idle nulls leave the dwell able to arm and fire"
    );

    dwell.update(null);
    dwell.update("candidate");
    dwell.update(null);
    await settled();
    assert.deepEqual(seen, ["candidate"], "the cancelled dwell never fires");
  });

  test("the same identity can dwell again after reset()", async function (assert) {
    const seen: string[] = [];
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      onDwell: (target: string) => seen.push(target),
    });

    dwell.update("candidate");
    await settled();

    dwell.reset();
    dwell.update("candidate");
    await settled();
    assert.deepEqual(
      seen,
      ["candidate", "candidate"],
      "reset() clears the latched identity"
    );
  });

  test("the same identity can dwell again after leaving via null and returning", async function (assert) {
    const seen: string[] = [];
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      onDwell: (target: string) => seen.push(target),
    });

    dwell.update("candidate");
    await settled();

    dwell.update(null);
    dwell.update("candidate");
    await settled();
    assert.deepEqual(
      seen,
      ["candidate", "candidate"],
      "a null report clears the latched identity"
    );
  });

  test("reset() is idempotent and leaves the dwell usable", async function (assert) {
    const seen: string[] = [];
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      onDwell: (target: string) => seen.push(target),
    });

    dwell.reset();
    dwell.reset();

    dwell.update("candidate");
    dwell.reset();
    dwell.reset();
    await settled();
    assert.deepEqual(seen, [], "the cancelled dwell never fires");

    dwell.update("candidate");
    await settled();
    assert.deepEqual(seen, ["candidate"], "still usable after resets");
  });

  test("destroying the destroyable cancels the pending dwell and disables firing", async function (assert) {
    const seen: string[] = [];
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      onDwell: (target: string) => seen.push(target),
    });

    dwell.update("candidate");
    destroy(parent);
    await settled();
    assert.deepEqual(seen, [], "the armed dwell never fires after destroy");

    dwell.update("candidate");
    await settled();
    assert.deepEqual(seen, [], "a report after destroy cannot fire either");
  });

  test("a report after destroy arms no timer at all", async function (assert) {
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      onDwell: () => {},
    });

    destroy(parent);
    await settled();

    const clock = sinon.useFakeTimers({
      now: Date.now(),
      shouldAdvanceTime: false,
    });
    try {
      dwell.update("candidate");
      assert.strictEqual(
        clock.countTimers(),
        0,
        "no timer is scheduled once the destroyable is gone"
      );
      // Drains the orphan a failing run leaves behind, so only the assertion
      // above reports.
      clock.tick(20);
    } finally {
      clock.restore();
    }
  });

  test("fires with the latest same-identity object, not the arming one", async function (assert) {
    const seen: { id: number; tag: string }[] = [];
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      identity: (target: { id: number; tag: string }) => target.id,
      onDwell: (target: { id: number; tag: string }) => seen.push(target),
    });

    dwell.update({ id: 1, tag: "armed" });
    dwell.update({ id: 1, tag: "fresh" });
    await settled();

    assert.strictEqual(seen.length, 1, "fires once");
    assert.strictEqual(seen[0]?.tag, "fresh", "with the latest object");
  });

  test("a custom identity dedups fresh per-report objects onto one dwell", function (assert) {
    const clock = sinon.useFakeTimers({
      now: Date.now(),
      shouldAdvanceTime: false,
    });

    try {
      const element = { name: "shared element" };
      const seen: { element: object }[] = [];
      const dwell = createDragDwell({
        destroyable: parent,
        delay: 300,
        identity: (target: { element: object }) => target.element,
        onDwell: (target: { element: object }) => seen.push(target),
      });

      dwell.update({ element });
      clock.tick(6);
      dwell.update({ element });
      clock.tick(6);

      // Past the collapsed 10ms deadline: fresh wrapper objects sharing one
      // identity kept the original timer rather than restarting it.
      assert.strictEqual(seen.length, 1, "fires exactly once");
      assert.strictEqual(seen[0]?.element, element, "for the shared identity");
    } finally {
      clock.restore();
    }
  });

  test("the default identity is the target reference itself", function (assert) {
    const clock = sinon.useFakeTimers({
      now: Date.now(),
      shouldAdvanceTime: false,
    });

    try {
      const target = { label: "candidate" };
      const seen: object[] = [];
      const dwell = createDragDwell({
        destroyable: parent,
        delay: 300,
        onDwell: (reported: object) => seen.push(reported),
      });

      dwell.update(target);
      clock.tick(6);
      dwell.update(target);
      clock.tick(6);

      // Past the collapsed 10ms deadline: the repeated reference kept the
      // original timer, so reference equality is the key.
      assert.deepEqual(seen, [target], "one identity, one fire");
    } finally {
      clock.restore();
    }
  });

  test("onDwell may reset and re-arm the same identity reentrantly", async function (assert) {
    const seen: string[] = [];
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      onDwell: (target: string) => {
        seen.push(target);
        if (seen.length === 1) {
          dwell.reset();
          dwell.update(target);
        }
      },
    });

    dwell.update("candidate");
    await settled();
    assert.deepEqual(
      seen,
      ["candidate", "candidate"],
      "the reentrant re-arm fired a second dwell"
    );
  });

  test("a throwing onDwell leaves the identity latched until reset", async function (assert) {
    const caught: unknown[] = [];
    setupOnerror((error: unknown) => caught.push(error));

    try {
      const seen: string[] = [];
      let throwOnce = true;
      const dwell = createDragDwell({
        destroyable: parent,
        delay: 300,
        onDwell: (target: string) => {
          if (throwOnce) {
            throwOnce = false;
            throw new Error("consumer failure");
          }
          seen.push(target);
        },
      });

      dwell.update("candidate");
      await settled();
      assert.strictEqual(caught.length, 1, "the throw surfaced via onerror");

      dwell.update("candidate");
      await settled();
      assert.deepEqual(seen, [], "the latched identity did not re-fire");

      dwell.reset();
      dwell.update("candidate");
      await settled();
      assert.deepEqual(seen, ["candidate"], "reset() unlatches it");
    } finally {
      resetOnerror();
    }
  });

  test("an identity function returning NaN is a stable key", function (assert) {
    const clock = sinon.useFakeTimers({
      now: Date.now(),
      shouldAdvanceTime: false,
    });

    try {
      const seen: object[] = [];
      const dwell = createDragDwell({
        destroyable: parent,
        delay: 300,
        identity: () => NaN,
        onDwell: (target: object) => seen.push(target),
      });

      dwell.update({ frame: 1 });
      clock.tick(6);
      dwell.update({ frame: 2 });
      clock.tick(6);

      // 12ms is past the collapsed 10ms deadline; a comparison for which NaN
      // is not equal to itself would have restarted the timer and need 16ms.
      assert.strictEqual(
        seen.length,
        1,
        "NaN compares equal to itself as a key"
      );
    } finally {
      clock.restore();
    }
  });

  test("an identity function returning null is a real key, and null reports never reach it", async function (assert) {
    const seen: object[] = [];
    const identityArgs: object[] = [];
    const dwell = createDragDwell({
      destroyable: parent,
      delay: 300,
      identity: (target: object) => {
        identityArgs.push(target);
        return null;
      },
      onDwell: (target: object) => seen.push(target),
    });

    dwell.update({ frame: 1 });
    dwell.update({ frame: 2 });
    dwell.update(null);
    await settled();

    assert.deepEqual(seen, [], "the null report cancelled the dwell");
    assert.strictEqual(
      identityArgs.length,
      2,
      "identity saw only the non-null reports"
    );

    dwell.update({ frame: 3 });
    await settled();
    assert.strictEqual(seen.length, 1, "the null key re-arms after clearing");
  });

  test("an identity function returning undefined is a real key, not a fallback", function (assert) {
    const clock = sinon.useFakeTimers({
      now: Date.now(),
      shouldAdvanceTime: false,
    });

    try {
      const seen: object[] = [];
      const dwell = createDragDwell({
        destroyable: parent,
        delay: 300,
        identity: () => undefined,
        onDwell: (target: object) => seen.push(target),
      });

      dwell.update({ frame: 1 });
      clock.tick(6);
      dwell.update({ frame: 2 });
      clock.tick(6);

      // An implementation that fell back to the fresh target object whenever
      // identity returned undefined would have restarted the timer at 6ms and
      // still be pending here at 12ms.
      assert.strictEqual(seen.length, 1, "the undefined key held the dwell");
    } finally {
      clock.restore();
    }
  });
});
