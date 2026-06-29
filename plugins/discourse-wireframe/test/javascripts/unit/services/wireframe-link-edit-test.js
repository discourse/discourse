import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

// The popover-driven edit/confirm/cancel flow is exercised end-to-end by the
// block-chrome-click integration test (through the kernel facade). These cases
// cover the service's wiring and its guard paths, which need no rendered layout.
module(
  "Unit | Discourse Wireframe | service:wireframe-link-edit",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.linkEdit = getOwner(this).lookup("service:wireframe-link-edit");
    });

    test("no session is active initially", function (assert) {
      assert.strictEqual(this.linkEdit.blockKey, null);
      assert.strictEqual(this.linkEdit.argName, null);
    });

    test("start on an unresolvable key opens no session", function (assert) {
      this.linkEdit.start({ blockKey: "wf:cta:missing", argName: "href" });
      assert.strictEqual(this.linkEdit.blockKey, null);
      assert.strictEqual(this.linkEdit.argName, null);
    });

    test("stop is idempotent and clears the session", function (assert) {
      this.linkEdit.stop();
      assert.strictEqual(this.linkEdit.blockKey, null);
      this.linkEdit.stop();
      assert.strictEqual(this.linkEdit.argName, null);
    });
  }
);
