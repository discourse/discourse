import { module, test } from "qunit";
import DragSessionState from "discourse/plugins/discourse-wireframe/discourse/lib/drag-session-state";

// `DragSessionState` is a pure, dependency-free leaf: it records what's being
// dragged and exposes read-only getters. `isDragging` tracks an EXISTING-block
// drag only — a palette (new-block) drag carries no source block.
module("Unit | Discourse Wireframe | lib:drag-session-state", function () {
  test("starts idle", function (assert) {
    const session = new DragSessionState();
    assert.strictEqual(session.sourceKey, null);
    assert.strictEqual(session.sourceOutlet, null);
    assert.false(session.isDragging);
  });

  test("beginBlock records the source and flips isDragging", function (assert) {
    const session = new DragSessionState();
    session.beginBlock({ blockKey: "para:1", outletName: "homepage-blocks" });

    assert.strictEqual(session.sourceKey, "para:1");
    assert.strictEqual(session.sourceOutlet, "homepage-blocks");
    assert.true(session.isDragging);
  });

  test("beginPalette starts a drag but isDragging stays false", function (assert) {
    const session = new DragSessionState();
    session.beginPalette({ blockName: "hero", defaultArgs: {} });

    assert.strictEqual(
      session.sourceKey,
      null,
      "a palette drag carries no source block"
    );
    assert.false(
      session.isDragging,
      "isDragging is false during a palette drag"
    );
  });

  test("clear resets all state", function (assert) {
    const session = new DragSessionState();
    session.beginBlock({ blockKey: "para:1", outletName: "homepage-blocks" });
    session.clear();

    assert.strictEqual(session.sourceKey, null);
    assert.strictEqual(session.sourceOutlet, null);
    assert.false(session.isDragging);
  });
});
