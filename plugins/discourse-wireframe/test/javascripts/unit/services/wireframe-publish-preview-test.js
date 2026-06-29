import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

// The drawer-driven preview (change counts + raw JSON) is exercised end-to-end
// by the publish-review-drawer integration test (through the kernel facade).
// These cases cover the service's wiring and its empty/unresolvable-outlet paths.
module(
  "Unit | Discourse Wireframe | service:wireframe-publish-preview",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.preview = getOwner(this).lookup("service:wireframe-publish-preview");
    });

    test("outletLayoutJson is an empty array for an unresolvable outlet", function (assert) {
      assert.strictEqual(
        this.preview.outletLayoutJson("homepage-blocks:missing"),
        "[]"
      );
    });

    test("outletChangeSummary reports no changes for an unedited outlet", function (assert) {
      const summary = this.preview.outletChangeSummary(
        "homepage-blocks:missing"
      );
      assert.strictEqual(summary.added, 0);
      assert.strictEqual(summary.removed, 0);
      assert.strictEqual(summary.moved, 0);
      assert.strictEqual(summary.edited, 0);
    });
  }
);
