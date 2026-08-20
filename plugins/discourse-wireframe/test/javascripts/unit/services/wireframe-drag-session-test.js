import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

// `wireframe-drag-session` is a dependency-free signal service: it records what's
// being dragged and exposes read-only getters. `isDragging` tracks an
// EXISTING-block drag only — a palette (new-block) drag carries no source block.
// It's an app singleton, so each test resets it in afterEach.
module(
  "Unit | Discourse Wireframe | service:wireframe-drag-session",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.session = getOwner(this).lookup("service:wireframe-drag-session");
    });

    hooks.afterEach(function () {
      this.session.clear();
    });

    test("starts idle", function (assert) {
      assert.strictEqual(this.session.sourceKey, null);
      assert.strictEqual(this.session.sourceOutlet, null);
      assert.false(this.session.isDragging);
    });

    test("beginBlock records the source and flips isDragging", function (assert) {
      this.session.beginBlock({
        blockKey: "para:1",
        outletName: "homepage-blocks",
      });

      assert.strictEqual(this.session.sourceKey, "para:1");
      assert.strictEqual(this.session.sourceOutlet, "homepage-blocks");
      assert.true(this.session.isDragging);
    });

    test("beginPalette starts a drag but isDragging stays false", function (assert) {
      this.session.beginPalette({ blockName: "hero", defaultArgs: {} });

      assert.strictEqual(
        this.session.sourceKey,
        null,
        "a palette drag carries no source block"
      );
      assert.false(
        this.session.isDragging,
        "isDragging is false during a palette drag"
      );
    });

    test("clear resets all state", function (assert) {
      this.session.beginBlock({
        blockKey: "para:1",
        outletName: "homepage-blocks",
      });
      this.session.clear();

      assert.strictEqual(this.session.sourceKey, null);
      assert.strictEqual(this.session.sourceOutlet, null);
      assert.false(this.session.isDragging);
    });
  }
);
