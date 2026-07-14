import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module(
  "Unit | Discourse Wireframe | service:wireframe-force-expand",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.forceExpand = getOwner(this).lookup(
        "service:wireframe-force-expand"
      );
    });

    test("nothing is force-expanded initially", function (assert) {
      assert.false(this.forceExpand.isForceExpanded("wf:layout:1"));
    });

    test("toggle flips a key on and off", function (assert) {
      this.forceExpand.toggleForceExpand("wf:layout:1");
      assert.true(this.forceExpand.isForceExpanded("wf:layout:1"));
      this.forceExpand.toggleForceExpand("wf:layout:1");
      assert.false(this.forceExpand.isForceExpanded("wf:layout:1"));
    });

    test("keys are tracked independently", function (assert) {
      this.forceExpand.toggleForceExpand("wf:layout:1");
      assert.true(this.forceExpand.isForceExpanded("wf:layout:1"));
      assert.false(this.forceExpand.isForceExpanded("wf:layout:2"));
    });

    test("a null/empty key is never force-expanded", function (assert) {
      assert.false(this.forceExpand.isForceExpanded(null));
      assert.false(this.forceExpand.isForceExpanded(""));
    });

    test("reset clears every force-expanded key", function (assert) {
      this.forceExpand.toggleForceExpand("wf:layout:1");
      this.forceExpand.toggleForceExpand("wf:layout:2");
      this.forceExpand.reset();
      assert.false(this.forceExpand.isForceExpanded("wf:layout:1"));
      assert.false(this.forceExpand.isForceExpanded("wf:layout:2"));
    });
  }
);
