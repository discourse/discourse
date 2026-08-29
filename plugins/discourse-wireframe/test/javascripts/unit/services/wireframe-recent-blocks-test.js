import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

// Mirrors the service's `RECENT_BLOCKS_LIMIT`; a literal so a change to the
// limit is a deliberate edit here too.
const RECENT_BLOCKS_LIMIT = 6;

module(
  "Unit | Discourse Wireframe | service:wireframe-recent-blocks",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.theme = getOwner(this).lookup("service:wireframe-publish-target");
      this.recent = getOwner(this).lookup("service:wireframe-recent-blocks");
    });

    test("records the most recent insert first, without repeats", function (assert) {
      this.theme.setActiveTheme(7);

      this.recent.record("heading");
      this.recent.record("paragraph");
      this.recent.record("heading");

      assert.deepEqual(this.recent.names, ["heading", "paragraph"]);
    });

    test("keeps only the newest entries once the limit is reached", function (assert) {
      this.theme.setActiveTheme(7);

      for (let i = 0; i <= RECENT_BLOCKS_LIMIT; i++) {
        this.recent.record(`block-${i}`);
      }

      assert.strictEqual(this.recent.names.length, RECENT_BLOCKS_LIMIT);
      assert.strictEqual(this.recent.names[0], `block-${RECENT_BLOCKS_LIMIT}`);
      assert.false(
        this.recent.names.includes("block-0"),
        "the oldest entry fell off"
      );
    });

    test("keeps a separate list per theme being edited", function (assert) {
      this.theme.setActiveTheme(7);
      this.recent.record("heading");

      this.theme.setActiveTheme(8);
      assert.deepEqual(this.recent.names, [], "a different theme starts empty");
      this.recent.record("card");

      this.theme.setActiveTheme(7);
      assert.deepEqual(this.recent.names, ["heading"]);
    });

    test("records nothing without a theme to attribute it to", function (assert) {
      this.recent.record("heading");
      assert.deepEqual(this.recent.names, []);
    });

    test("survives a fresh service instance", function (assert) {
      this.theme.setActiveTheme(7);
      this.recent.record("heading");

      const owner = getOwner(this);
      owner.unregister("service:wireframe-recent-blocks");
      const again = owner.lookup("service:wireframe-recent-blocks");

      assert.deepEqual(again.names, ["heading"]);
    });
  }
);
