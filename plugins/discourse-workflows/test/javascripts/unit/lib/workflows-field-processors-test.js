import { module, test } from "qunit";
import processFields from "discourse/plugins/discourse-workflows/admin/lib/workflows/field-processors";

module("Unit | lib | discourse-workflows | field-processors", function () {
  test("returns fields unchanged when no form_data field exists", function (assert) {
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

    const result = processFields(fields, node, graph);
    assert.deepEqual(result, fields);
  });

  test("returns fields unchanged when form_data exists but node has no ancestors", function (assert) {
    const node = {
      clientId: "node1",
      type: "action:http_request",
      configuration: {},
    };
    const graph = { nodes: [node], connections: [], nodeTypes: [] };
    const fields = [
      {
        key: "form_data",
        type: "object",
        id: "form_data",
        children: [{ key: "name", type: "string", id: "name" }],
      },
    ];

    const result = processFields(fields, node, graph);
    assert.deepEqual(result, fields);
  });

  test("preserves non-form_data fields untouched alongside form_data", function (assert) {
    const trigger = {
      clientId: "trigger",
      type: "trigger:manual",
      configuration: {},
    };
    const action = {
      clientId: "action",
      type: "action:http_request",
      configuration: {},
    };
    const graph = {
      nodes: [trigger, action],
      connections: [{ sourceClientId: "trigger", targetClientId: "action" }],
      nodeTypes: [{ identifier: "trigger:manual", output_schema: {} }],
    };
    const fields = [
      { key: "url", type: "string", id: "url" },
      {
        key: "form_data",
        type: "object",
        id: "form_data",
        children: [{ key: "name", type: "string", id: "name" }],
      },
    ];

    const result = processFields(fields, action, graph);
    assert.strictEqual(result.length, 2);
    assert.strictEqual(result[0].key, "url");
    assert.strictEqual(result[1].key, "form_data");
  });

  test("does not duplicate keys already present in own form_data", function (assert) {
    const trigger = {
      clientId: "trigger",
      type: "trigger:form",
      configuration: {
        form_fields: [{ field_label: "Name", field_type: "text" }],
      },
    };
    const action = {
      clientId: "action",
      type: "action:http_request",
      configuration: {},
    };
    const graph = {
      nodes: [trigger, action],
      connections: [{ sourceClientId: "trigger", targetClientId: "action" }],
      nodeTypes: [],
    };
    const fields = [
      {
        key: "form_data",
        type: "object",
        id: "form_data",
        children: [{ key: "name", type: "string", id: "name" }],
      },
    ];

    const result = processFields(fields, action, graph);
    const formData = result.find((f) => f.key === "form_data");
    const nameFields = formData.children.filter((c) => c.key === "name");
    assert.strictEqual(nameFields.length, 1);
  });

  test("merges ancestor form_data children into current node's form_data", function (assert) {
    const trigger = {
      clientId: "trigger",
      type: "trigger:form",
      configuration: {
        form_fields: [
          { field_label: "Email", field_type: "text" },
          { field_label: "Phone", field_type: "text" },
        ],
      },
    };
    const action = {
      clientId: "action",
      type: "action:http_request",
      configuration: {},
    };
    const graph = {
      nodes: [trigger, action],
      connections: [{ sourceClientId: "trigger", targetClientId: "action" }],
      nodeTypes: [],
    };
    const fields = [
      {
        key: "form_data",
        type: "object",
        id: "form_data",
        children: [{ key: "extra_field", type: "string", id: "extra_field" }],
      },
    ];

    const result = processFields(fields, action, graph);
    const formData = result.find((f) => f.key === "form_data");
    const keys = formData.children.map((c) => c.key);
    assert.true(keys.includes("email"));
    assert.true(keys.includes("phone"));
    assert.true(keys.includes("extra_field"));
    assert.strictEqual(formData.children.length, 3);
  });
});
