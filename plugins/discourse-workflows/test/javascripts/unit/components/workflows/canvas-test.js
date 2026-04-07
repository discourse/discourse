import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import WorkflowCanvas from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas";

module("Unit | Component | workflows canvas", function (hooks) {
  setupTest(hooks);

  test("autoLayout is defined on the prototype", function (assert) {
    assert.true(
      "autoLayout" in WorkflowCanvas.prototype,
      "autoLayout action exists"
    );
  });
});
