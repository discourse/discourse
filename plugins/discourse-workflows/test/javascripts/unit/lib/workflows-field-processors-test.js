import { module, test } from "qunit";
import processFields from "discourse/plugins/discourse-workflows/admin/lib/workflows/field-processors";

module("Unit | lib | discourse-workflows | field-processors", function () {
  test("returns fields unchanged", function (assert) {
    const node = {
      clientId: "node1",
      type: "action:http_request",
      configuration: {},
    };
    const graph = { nodes: [node], connections: [], nodeTypes: [] };
    const fields = [
      { key: "url", type: "string", id: "url" },
      { key: "method", type: "string", id: "method" },
    ];

    assert.deepEqual(processFields(fields, node, graph), fields);
  });

  test("does not merge ancestor form fields into current form output", function (assert) {
    const trigger = {
      clientId: "trigger",
      type: "trigger:form",
      configuration: {
        form_fields: {
          values: [{ field_label: "Email", field_type: "text" }],
        },
      },
    };
    const action = {
      clientId: "action",
      type: "action:form",
      configuration: {},
    };
    const graph = {
      nodes: [trigger, action],
      connections: [{ sourceClientId: "trigger", targetClientId: "action" }],
      nodeTypes: [],
    };
    const fields = [
      { key: "feedback", type: "string", id: "feedback" },
      { key: "submitted_at", type: "string", id: "submitted_at" },
      { key: "form_mode", type: "string", id: "form_mode" },
    ];

    assert.deepEqual(processFields(fields, action, graph), fields);
  });
});
