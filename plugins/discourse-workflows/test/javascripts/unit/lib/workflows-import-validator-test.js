import { module, test } from "qunit";
import { i18n } from "discourse-i18n";
import { buildWorkflowFromJson } from "discourse/plugins/discourse-workflows/admin/lib/workflows/import-validator";

module("Unit | lib | discourse-workflows | import validator", function () {
  function error(key, options) {
    return i18n(`discourse_workflows.import_workflow.${key}`, options);
  }

  function validJson(overrides = {}) {
    return JSON.stringify({
      name: "Imported workflow",
      nodes: [
        {
          id: "n1",
          type: "trigger:manual",
          typeVersion: 1,
          name: "Manual trigger",
        },
        {
          id: "n2",
          type: "action:set-variable",
          name: "Set variable",
          position: { x: 10, y: 20 },
        },
      ],
      // Default to no connections so tests that replace `nodes` do not leave
      // stale references to the default node names behind.
      connections: {},
      ...overrides,
    });
  }

  test("builds a workflow from valid JSON", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({
        connections: {
          "Manual trigger": {
            main: [[{ node: "Set variable", type: "main", index: 0 }]],
          },
        },
      })
    );

    assert.deepEqual(errors, []);
    assert.strictEqual(workflow.name, "Imported workflow");
    assert.strictEqual(workflow.nodes.length, 2);
    assert.deepEqual(workflow.nodes[0], {
      id: "n1",
      type: "trigger:manual",
      typeVersion: 1,
      name: "Manual trigger",
      parameters: {},
      credentials: {},
      webhookId: null,
      position: null,
    });
    assert.deepEqual(workflow.connections, {
      "Manual trigger": {
        main: [[{ node: "Set variable", type: "main", index: 0 }]],
      },
    });
  });

  test("passes nodes without ids or typeVersion through", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(validJson());

    assert.deepEqual(errors, []);
    assert.strictEqual(workflow.nodes[1].typeVersion, undefined);
    assert.strictEqual(workflow.nodes[1].id, "n2");
  });

  test("returns an empty error for blank input", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson("   ");

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("empty")]);
  });

  test("rejects invalid JSON", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson("{ not json");

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("invalid_json")]);
  });

  test("rejects a JSON array at the top level", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson("[1, 2, 3]");

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("invalid_payload")]);
  });

  test("requires a name", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(validJson({ name: "" }));

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("name_required")]);
  });

  test("uses a supplied name for a nameless graph or to rename an export", function (assert) {
    for (const name of [undefined, "", "Original name"]) {
      const result = buildWorkflowFromJson(validJson({ name }), {
        name: "  Typed name  ",
      });
      assert.deepEqual(result.errors, []);
      assert.strictEqual(result.workflow.name, "Typed name");
    }
  });

  test("a blank override falls back to the exported name", function (assert) {
    const result = buildWorkflowFromJson(validJson(), { name: "  " });
    assert.deepEqual(result.errors, []);
    assert.strictEqual(result.workflow.name, "Imported workflow");

    const missing = buildWorkflowFromJson(validJson({ name: undefined }), {
      name: "  ",
    });
    assert.strictEqual(missing.workflow, null);
    assert.deepEqual(missing.errors, [error("name_required")]);
  });

  test("requires nodes to be an array", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ nodes: "nope" })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("invalid_nodes")]);
  });

  test("requires at least one node", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ nodes: [] })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("nodes_required")]);
  });

  test("rejects node entries that are not objects", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ nodes: ["nope"] })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("invalid_node", { index: 1 })]);
  });

  test("requires each node to have a type", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ nodes: [{ name: "No type" }] })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("node_type_required", { index: 1 })]);
  });

  test("requires each node to have a name", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ nodes: [{ type: "trigger:manual" }] })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("node_name_required", { index: 1 })]);
  });

  test("rejects duplicate node names", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({
        nodes: [
          { type: "trigger:manual", name: "Duplicate" },
          { type: "action:set-variable", name: "Duplicate" },
        ],
      })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [
      error("duplicate_node_name", { name: "Duplicate" }),
    ]);
  });

  test("allows multiple sticky notes to share a name", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({
        nodes: [
          { type: "flow:sticky_note", name: "Sticky Note" },
          { type: "flow:sticky_note", name: "Sticky Note" },
          { type: "trigger:manual", name: "Manual trigger" },
        ],
      })
    );

    assert.deepEqual(errors, []);
    assert.strictEqual(workflow.nodes.length, 3);
  });

  test("rejects a sticky note name shared with an executable node", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({
        nodes: [
          { type: "trigger:manual", name: "Shared" },
          { type: "flow:sticky_note", name: "Shared" },
        ],
      })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [
      error("duplicate_node_name", { name: "Shared" }),
    ]);
  });

  test("rejects unsupported snake_case node keys", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({
        nodes: [{ type: "trigger:manual", name: "Legacy", settings: {} }],
      })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [
      error("unsupported_node_key", { key: "settings", index: 1 }),
    ]);
  });

  test("rejects workflows with more than 50 nodes", function (assert) {
    const nodes = Array.from({ length: 51 }, (_, index) => ({
      type: "action:set-variable",
      name: `Node ${index}`,
    }));
    const { workflow, errors } = buildWorkflowFromJson(validJson({ nodes }));

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("too_many_nodes", { count: 51, max: 50 })]);
  });

  test("requires connections to be an object", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ connections: [] })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("invalid_connections")]);
  });

  test("rejects connections that reference an unknown source node", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ connections: { Ghost: { main: [] } } })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [
      error("unknown_connection_source", { node: "Ghost" }),
    ]);
  });

  test("rejects connections that reference an unknown target node", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({
        connections: {
          "Manual trigger": { main: [[{ node: "Ghost", type: "main" }]] },
        },
      })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [
      error("unknown_connection_target", { node: "Ghost" }),
    ]);
  });

  test("returns no errors when connections are omitted", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ connections: undefined })
    );

    assert.deepEqual(errors, []);
    assert.deepEqual(workflow.connections, {});
  });

  test("preserves variables and staticData from an export", function (assert) {
    const variables = [
      {
        key: "audience",
        description: "Who to target",
        variable_type: "string",
      },
    ];
    const staticData = { "Manual trigger": { cursor: "abc" } };
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ variables, staticData })
    );

    assert.deepEqual(errors, []);
    assert.deepEqual(workflow.variables, variables);
    assert.deepEqual(workflow.staticData, staticData);
  });

  test("preserves settings from an export", function (assert) {
    const settings = { timezone: "Europe/Paris" };
    const { workflow, errors } = buildWorkflowFromJson(validJson({ settings }));

    assert.deepEqual(errors, []);
    assert.deepEqual(workflow.settings, settings);
  });

  test("rejects settings that are not an object", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ settings: "nope" })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("invalid_settings")]);
  });

  test("rejects a settings timezone that is not a string", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ settings: { timezone: 123 } })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("invalid_settings")]);
  });

  test("rejects unknown, blank, and incorrectly cased timezones", function (assert) {
    for (const timezone of ["UTC+2", "", " ", "europe/paris"]) {
      const result = buildWorkflowFromJson(
        validJson({ settings: { timezone } })
      );
      assert.strictEqual(result.workflow, null, timezone);
      assert.deepEqual(result.errors, [error("invalid_settings")], timezone);
    }
  });

  test("accepts UTC, timezone aliases, and omitted timezones", function (assert) {
    for (const settings of [
      { timezone: "UTC" },
      { timezone: "US/Eastern" },
      {},
    ]) {
      const result = buildWorkflowFromJson(validJson({ settings }));
      assert.deepEqual(result.errors, []);
      assert.deepEqual(result.workflow.settings, settings);
    }
  });

  test("rejects a staticData field that is not a node map", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ staticData: ["nope"] })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("invalid_static_data")]);
  });

  test("rejects a staticData map whose value is not an object", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ staticData: { "Manual trigger": "nope" } })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("invalid_static_data")]);
  });

  test("rejects variables that are not an array of definitions", function (assert) {
    const { workflow, errors } = buildWorkflowFromJson(
      validJson({ variables: ["nope"] })
    );

    assert.strictEqual(workflow, null);
    assert.deepEqual(errors, [error("invalid_variables")]);
  });
});
