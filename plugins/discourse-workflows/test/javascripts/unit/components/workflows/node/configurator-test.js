import { module, test } from "qunit";
import NodeConfigurator from "discourse/plugins/discourse-workflows/admin/components/workflows/node/configurator";

function buildConfigurator(model) {
  const configurator = Object.create(NodeConfigurator.prototype);

  Object.defineProperty(configurator, "args", { value: { model } });

  return configurator;
}

module("Unit | Component | Workflows | Node | Configurator", function () {
  test("disables execute step inside submission check workflows", function (assert) {
    const node = {
      clientId: "reject-1",
      name: "Reject submission",
      type: "action:reject_submission",
      typeVersion: "1.0",
    };

    const ordinary = buildConfigurator({
      node,
      nodes: [{ type: "trigger:manual" }],
    });
    assert.true(ordinary.showExecuteStep, "the button is offered");
    assert.true(ordinary.isExecuteStepEnabled, "the step can be executed");

    const submission = buildConfigurator({
      node,
      nodes: [{ type: "trigger:before_post_submission" }, node],
    });
    assert.true(submission.showExecuteStep, "the button is still offered");
    assert.false(
      submission.isExecuteStepEnabled,
      "the step cannot be executed in a submission check workflow"
    );
  });

  test("disables execute step for unavailable nodes", function (assert) {
    const configurator = buildConfigurator({
      node: { type: "action:post" },
      nodes: [{ type: "trigger:manual" }],
    });
    Object.defineProperty(configurator, "resolvedNodeType", {
      value: { available: false },
    });

    assert.false(
      configurator.isExecuteStepEnabled,
      "an unavailable action cannot be executed"
    );
  });

  test("does not offer execute step for trigger nodes", function (assert) {
    const configurator = buildConfigurator({
      node: {
        clientId: "trigger-1",
        name: "Before post submission",
        type: "trigger:before_post_submission",
        typeVersion: "1.0",
      },
      nodes: [{ type: "trigger:before_post_submission" }],
    });

    assert.false(configurator.showExecuteStep);
  });
});
