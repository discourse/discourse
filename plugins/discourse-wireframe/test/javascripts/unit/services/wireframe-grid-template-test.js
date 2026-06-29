import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

// The apply / reflow / clamp logic is exercised end-to-end against real grid
// layouts by the inspector-layout-form integration test and the wireframe-test
// grid scenarios (through the kernel facades). These cases cover the service's
// wiring and its early-return guards, which need no rendered layout.
module(
  "Unit | Discourse Wireframe | service:wireframe-grid-template",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.gridTemplate = getOwner(this).lookup(
        "service:wireframe-grid-template"
      );
    });

    test("canApplyGridTemplate is false without a template", function (assert) {
      assert.false(
        this.gridTemplate.canApplyGridTemplate({
          gridKey: "wf:layout:1",
          template: null,
        })
      );
    });

    test("applyGridTemplate no-ops without a template", function (assert) {
      assert.false(
        this.gridTemplate.applyGridTemplate({
          gridKey: "wf:layout:1",
          template: null,
        })
      );
    });

    test("outOfBoundsSlotsIn is empty for an unresolvable grid", function (assert) {
      assert.deepEqual(
        this.gridTemplate.outOfBoundsSlotsIn("wf:layout:missing", 3, 2),
        []
      );
    });

    test("activeGridTemplate is null for an unresolvable grid", function (assert) {
      assert.strictEqual(
        this.gridTemplate.activeGridTemplate("wf:layout:missing"),
        null
      );
    });
  }
);
