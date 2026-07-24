import { module, test } from "qunit";
import { workflowFromTemplate } from "discourse/plugins/discourse-workflows/admin/lib/workflows/template-workflow";

module("Unit | lib | discourse-workflows | template workflow", function () {
  test("builds workflow attributes from template JSON", function (assert) {
    const workflow = workflowFromTemplate({
      name: "Template workflow",
      nodes: [
        {
          id: "n1",
          type: "trigger:manual",
          typeVersion: 1,
          name: "Manual trigger",
          parameters: { value: "x" },
          credentials: { api: { id: 1 } },
          webhookId: "webhook-1",
          position: { x: 10, y: 20 },
          notes: "Template note",
        },
      ],
      connections: {
        "Manual trigger": {
          main: [],
        },
      },
    });

    assert.deepEqual(workflow, {
      name: "Template workflow",
      nodes: [
        {
          id: "n1",
          type: "trigger:manual",
          typeVersion: 1,
          name: "Manual trigger",
          parameters: { value: "x" },
          credentials: { api: { id: 1 } },
          webhookId: "webhook-1",
          position: { x: 10, y: 20 },
          notes: "Template note",
        },
      ],
      connections: {
        "Manual trigger": {
          main: [],
        },
      },
    });
  });
});
