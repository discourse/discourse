import { module, test } from "qunit";
import {
  shouldEnableExecuteStep,
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

  test("disables manual trigger inside submission check workflows", function (assert) {
    const node = {
      name: "Before post submission",
      type: "trigger:before_post_submission",
      typeVersion: "1.0",
    };
    const nodeType = {
      capabilities: {
        manually_triggerable: true,
      },
    };

    assert.true(shouldEnableManualTrigger(node, nodeType));
    assert.false(shouldEnableManualTrigger(node, nodeType, null, true));
    assert.false(
      shouldEnableManualTrigger(
        node,
        nodeType,
        {
          isNodePinned() {
            return true;
          },
        },
        true
      )
    );
  });

  test("disables execute step inside submission check workflows", function (assert) {
    const node = {
      name: "Reject submission",
      type: "action:reject_submission",
      typeVersion: "1.0",
    };

    assert.true(shouldEnableExecuteStep(node));
    assert.false(shouldEnableExecuteStep(node, true));
    assert.false(
      shouldEnableExecuteStep(
        {
          name: "Before post submission",
          type: "trigger:before_post_submission",
          typeVersion: "1.0",
        },
        false
      )
    );
  });
});
