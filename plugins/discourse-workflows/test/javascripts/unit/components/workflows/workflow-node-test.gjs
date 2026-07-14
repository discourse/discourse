import { module, test } from "qunit";
import {
  shouldEnableManualTrigger,
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
