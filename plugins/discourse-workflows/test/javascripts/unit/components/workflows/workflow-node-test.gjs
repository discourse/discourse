import { module, test } from "qunit";
import {
  shouldEnableManualTrigger,
  shouldShowExecuteStep,
  shouldShowManualTrigger,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/workflow-node";

module("Unit | Component | Workflows | Canvas | WorkflowNode", function () {
  test("shows manual trigger for trigger nodes", function (assert) {
    assert.true(
      shouldShowManualTrigger({
        name: "Schedule",
        type: "trigger:schedule",
        typeVersion: "1.0",
      })
    );

    assert.true(
      shouldShowManualTrigger({
        name: "Post created",
        type: "trigger:post_created",
        typeVersion: "1.0",
      })
    );
  });

  test("only enables data-dependent triggers after pinning data", function (assert) {
    const node = {
      name: "Post created",
      type: "trigger:post_created",
      typeVersion: "1.0",
    };
    const nodeType = {
      capabilities: {
        manually_triggerable: false,
      },
    };

    assert.false(shouldEnableManualTrigger(node, nodeType));
    assert.false(
      shouldEnableManualTrigger(node, nodeType, {
        isNodePinned() {
          return false;
        },
      })
    );
    assert.true(
      shouldEnableManualTrigger(node, nodeType, {
        isNodePinned(nodeName) {
          assert.strictEqual(nodeName, "Post created");
          return true;
        },
      })
    );
  });

  test("enables a trigger with a launch path once the workflow is saved", function (assert) {
    const node = {
      name: "Launchable",
      type: "trigger:launchable",
      typeVersion: "1.0",
    };
    const nodeType = {
      capabilities: { launch_path: "/launch/:workflow_id/:node_id" },
    };
    const session = {
      workflowId: 7,
      isNodePinned() {
        return false;
      },
    };

    assert.true(shouldEnableManualTrigger(node, nodeType, session));
    assert.false(
      shouldEnableManualTrigger(node, nodeType, {
        ...session,
        workflowId: null,
      }),
      "needs a saved workflow"
    );
    assert.false(
      shouldEnableManualTrigger(
        node,
        { ...nodeType, available: false },
        session
      ),
      "needs an available node type"
    );
    assert.false(shouldEnableManualTrigger(node, undefined, session));
  });

  test("shows execute step only for non-trigger nodes", function (assert) {
    assert.true(
      shouldShowExecuteStep({
        name: "HTTP request",
        type: "action:http_request",
        typeVersion: "1.0",
      })
    );
    assert.true(
      shouldShowExecuteStep({
        name: "If",
        type: "condition:if",
        typeVersion: "1.0",
      })
    );

    assert.false(
      shouldShowExecuteStep({
        name: "Post created",
        type: "trigger:post_created",
        typeVersion: "1.0",
      })
    );
    assert.false(shouldShowExecuteStep({ name: "No type" }));
    assert.false(shouldShowExecuteStep(undefined));
  });

  test("does not show or enable manual trigger for action nodes with pinned data", function (assert) {
    assert.false(
      shouldShowManualTrigger({
        name: "HTTP request",
        type: "action:http_request",
        typeVersion: "1.0",
      })
    );
    assert.false(
      shouldEnableManualTrigger(
        {
          name: "HTTP request",
          type: "action:http_request",
          typeVersion: "1.0",
        },
        {
          capabilities: {
            manually_triggerable: true,
          },
        },
        {
          isNodePinned() {
            return true;
          },
        }
      )
    );
  });
});
