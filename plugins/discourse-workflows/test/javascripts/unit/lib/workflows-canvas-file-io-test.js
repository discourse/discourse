import { module, test } from "qunit";
import {
  buildWorkflowExportPayload,
  parseWorkflowImport,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/canvas-file-io";
import { mergeImportedStaticData } from "discourse/plugins/discourse-workflows/admin/lib/workflows/static-data";
import WorkflowNode from "discourse/plugins/discourse-workflows/admin/models/workflow-node";

module("Unit | lib | discourse-workflows | canvas-file-io", function () {
  test("buildWorkflowExportPayload returns workflow JSON", function (assert) {
    const node = WorkflowNode.create({
      clientId: "node-1",
      type: "action:http_request",
      typeVersion: "1.0",
      name: "Send request",
      configuration: {
        method: "GET",
        url: "https://example.com",
        alwaysOutputData: true,
        authentication: "bearer_token",
        credentials: {
          auth: {
            id: "42",
            credential_type: "bearer_token",
          },
        },
      },
    });

    const payload = buildWorkflowExportPayload([node], [], [], {
      id: 42,
      name: "Imported workflow",
      settings: { executionOrder: "v1" },
      staticData: { "node:Send request": { count: 1 } },
      pinData: { "node-1": [{ json: { ok: true } }] },
      versionId: "version-1",
      activeVersionId: "version-1",
      versionCounter: 3,
    });

    assert.strictEqual(payload.id, "42");
    assert.strictEqual(payload.name, "Imported workflow");
    assert.deepEqual(payload.settings, { executionOrder: "v1" });
    assert.deepEqual(payload.staticData, { "node:Send request": { count: 1 } });
    assert.deepEqual(payload.pinData, { "node-1": [{ json: { ok: true } }] });
    assert.strictEqual(payload.versionId, "version-1");
    assert.strictEqual(payload.activeVersionId, "version-1");
    assert.strictEqual(payload.versionCounter, 3);
    assert.deepEqual(payload.connections, {});
    assert.deepEqual(payload.nodes[0].credentials, {
      auth: {
        id: "42",
        credential_type: "bearer_token",
      },
    });
    assert.true(payload.nodes[0].alwaysOutputData);
    assert.false("settings" in payload.nodes[0]);
    assert.false("credentials" in payload.nodes[0].parameters);
  });

  test("buildWorkflowExportPayload serializes multi-output connections without null holes", function (assert) {
    const source = WorkflowNode.create({
      clientId: "node-1",
      type: "condition:if",
      typeVersion: "1.0",
      name: "If",
    });
    const target = WorkflowNode.create({
      clientId: "node-2",
      type: "action:log",
      typeVersion: "1.0",
      name: "Log",
    });

    const payload = buildWorkflowExportPayload(
      [source, target],
      [
        {
          sourceClientId: "node-1",
          targetClientId: "node-2",
          connectionType: "main",
          sourceOutputIndex: 1,
          targetInputIndex: 0,
        },
      ],
      []
    );

    assert.deepEqual(payload.connections, {
      If: {
        main: [[], [{ node: "Log", type: "main", index: 0 }]],
      },
    });
  });

  test("parseWorkflowImport strips credential references", function (assert) {
    const result = parseWorkflowImport(
      JSON.stringify({
        nodes: [
          {
            type: "action:http_request",
            typeVersion: "1.0",
            name: "Send request",
            parameters: {
              method: "GET",
              url: "https://example.com",
              authentication: "bearer_token",
              credentials: {
                auth: {
                  id: "99",
                  credential_type: "bearer_token",
                },
              },
            },
            credentials: {
              auth: {
                id: "42",
                credential_type: "bearer_token",
              },
            },
            notes: "Imported note",
            notesInFlow: false,
            alwaysOutputData: true,
          },
        ],
        connections: {},
      })
    );

    assert.deepEqual(result.nodes[0].credentials, {});
    assert.false("credentials" in result.nodes[0].parameters);
    assert.false("settings" in result.nodes[0]);
    assert.false("credentials" in result.nodes[0].configuration);
    assert.strictEqual(result.nodes[0].notes, "Imported note");
    assert.false(result.nodes[0].notesInFlow);
    assert.true(result.nodes[0].alwaysOutputData);
  });

  test("parseWorkflowImport preserves imported static data", function (assert) {
    const result = parseWorkflowImport(
      JSON.stringify({
        nodes: [
          {
            type: "action:log",
            typeVersion: "1.0",
            name: "Log",
            parameters: {},
          },
        ],
        connections: {},
        staticData: {
          global: {
            tenant_id: "acme",
          },
          "node:Log": {
            cursor: "abc",
          },
        },
      })
    );

    assert.deepEqual(result.staticData, {
      global: {
        tenant_id: "acme",
      },
      "node:Log": {
        cursor: "abc",
      },
    });
  });

  test("parseWorkflowImport rejects nested staticData node buckets", function (assert) {
    const result = parseWorkflowImport(
      JSON.stringify({
        nodes: [
          {
            type: "action:log",
            typeVersion: "1.0",
            name: "Log",
            parameters: {},
          },
        ],
        connections: {},
        staticData: {
          node: {
            Log: {},
          },
        },
      })
    );

    assert.deepEqual(result, { error: "invalid" });
  });

  test("parseWorkflowImport rejects non-object staticData slots", function (assert) {
    const result = parseWorkflowImport(
      JSON.stringify({
        nodes: [
          {
            type: "action:log",
            typeVersion: "1.0",
            name: "Log",
            parameters: {},
          },
        ],
        connections: {},
        staticData: {
          "node:Log": "bad",
        },
      })
    );

    assert.deepEqual(result, { error: "invalid" });
  });

  test("mergeImportedStaticData preserves existing runtime state while appending imported state", function (assert) {
    const result = mergeImportedStaticData(
      {
        global: {
          tenant_id: "acme",
          shared: "existing",
        },
        "node:Existing": {
          cursor: "existing",
        },
      },
      {
        global: {
          shared: "imported",
          imported: true,
        },
        "node:Imported": {
          cursor: "imported",
        },
      }
    );

    assert.deepEqual(result, {
      global: {
        tenant_id: "acme",
        shared: "imported",
        imported: true,
      },
      "node:Existing": {
        cursor: "existing",
      },
      "node:Imported": {
        cursor: "imported",
      },
    });
  });

  test("parseWorkflowImport rejects unsupported export format", function (assert) {
    const result = parseWorkflowImport(
      JSON.stringify({
        version: 2,
        nodes: [{ type: "action:log", type_version: "1.0", name: "Log" }],
        connections: [
          {
            source_index: 0,
            target_index: 1,
            connection_type: "main",
          },
        ],
      })
    );

    assert.deepEqual(result, { error: "invalid" });
  });

  test("parseWorkflowImport rejects unsupported node keys by key presence", function (assert) {
    for (const node of [
      { type: "action:log", type_version: "", name: "Log" },
      { type: "action:log", webhook_id: null, name: "Log" },
      { type: "action:log", position_index: 0, name: "Log" },
      { type: "action:log", settings: {}, name: "Log" },
    ]) {
      assert.deepEqual(
        parseWorkflowImport(JSON.stringify({ nodes: [node], connections: {} })),
        { error: "invalid" }
      );
    }
  });

  test("parseWorkflowImport rejects non-object workflow JSON", function (assert) {
    assert.deepEqual(parseWorkflowImport("null"), { error: "invalid" });
    assert.deepEqual(parseWorkflowImport("[]"), { error: "invalid" });
  });
});
