import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import WorkflowCanvas from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas";

module("Unit | Component | workflows canvas", function (hooks) {
  setupTest(hooks);

  test("Digit2 triggers auto layout", function (assert) {
    const component = new WorkflowCanvas(this.owner, {});
    const autoLayoutStub = sinon.stub(component, "autoLayout");

    component.handleKeyDown({
      code: "Digit2",
      key: "2",
      target: { tagName: "DIV" },
    });

    assert.true(autoLayoutStub.calledOnce);
  });
});
