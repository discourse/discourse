import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

// The picker-driven flow (menu open / select / undo) is exercised end-to-end via
// block-chrome (through the kernel facade). These cases cover the service's
// wiring and its guard paths, which need no rendered layout or open menu.
module(
  "Unit | Discourse Wireframe | service:wireframe-icon-edit",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.iconEdit = getOwner(this).lookup("service:wireframe-icon-edit");
    });

    test("no session is active initially", function (assert) {
      assert.strictEqual(this.iconEdit.blockKey, null);
      assert.strictEqual(this.iconEdit.argName, null);
    });

    test("start on an unresolvable key opens no session", async function (assert) {
      await this.iconEdit.start({
        blockKey: "wf:card:missing",
        argName: "icon",
        anchorEl: document.createElement("div"),
      });
      assert.strictEqual(this.iconEdit.blockKey, null);
      assert.strictEqual(this.iconEdit.argName, null);
    });

    test("stop is idempotent with no open menu", async function (assert) {
      await this.iconEdit.stop();
      assert.strictEqual(this.iconEdit.blockKey, null);
    });
  }
);
