import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module(
  "Unit | Discourse Wireframe | service:wireframe-revision",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.revision = getOwner(this).lookup("service:wireframe-revision");
    });

    test("starts at 0", function (assert) {
      assert.strictEqual(this.revision.version, 0);
    });

    test("bump increments the version monotonically", function (assert) {
      this.revision.bump();
      assert.strictEqual(this.revision.version, 1);
      this.revision.bump();
      assert.strictEqual(this.revision.version, 2);
    });
  }
);
