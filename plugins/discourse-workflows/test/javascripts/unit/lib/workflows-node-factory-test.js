import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { i18n } from "discourse-i18n";
import {
  createNode,
  takenNodeNames,
  uniqueNodeName,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/editor/node-factory";
import { FORM_TRIGGER_TYPE } from "discourse/plugins/discourse-workflows/admin/lib/workflows/node-data-shape";
import { STICKY_NOTE_NAME } from "discourse/plugins/discourse-workflows/admin/models/sticky-note";
import WorkflowNode from "discourse/plugins/discourse-workflows/admin/models/workflow-node";

module("Unit | lib | discourse-workflows | node-factory", function (hooks) {
  setupTest(hooks);

  test("createNode names a node after its i18n label, deduping against existing nodes", function (assert) {
    const baseName = i18n("discourse_workflows.nodes.trigger:webhook");

    assert.strictEqual(createNode("trigger:webhook", []).name, baseName);
    assert.strictEqual(
      createNode("trigger:webhook", [
        { name: baseName },
        { name: `${baseName} 1` },
      ]).name,
      `${baseName} 2`
    );
  });

  test("takenNodeNames reserves the sticky note name alongside existing names", function (assert) {
    const taken = takenNodeNames([{ name: "Foo step" }]);

    assert.true(taken.has(STICKY_NOTE_NAME), "sticky note name is reserved");
    assert.true(taken.has("Foo step"), "existing node names are taken");
  });

  test("uniqueNodeName keeps the base name when free and suffixes on collision", function (assert) {
    assert.strictEqual(uniqueNodeName("Foo step", new Set()), "Foo step");
    assert.strictEqual(
      uniqueNodeName("Foo step", new Set(["Foo step"])),
      "Foo step 1"
    );
    assert.strictEqual(
      uniqueNodeName("Foo step", new Set(["Foo step", "Foo step 1"])),
      "Foo step 2"
    );
  });

  test("createNode returns a node with correct type and default version", function (assert) {
    const node = createNode("trigger:webhook", []);
    assert.strictEqual(node.type, "trigger:webhook");
    assert.strictEqual(node.typeVersion, "1.0");
  });

  test("createNode generates a unique clientId for each call", function (assert) {
    const node1 = createNode("trigger:webhook", []);
    const node2 = createNode("trigger:webhook", []);
    assert.strictEqual(typeof node1.clientId, "string");
    assert.strictEqual(typeof node2.clientId, "string");
    assert.notStrictEqual(node1.clientId, node2.clientId);
  });

  test("createNode applies position when provided", function (assert) {
    const position = { x: 100, y: 200 };
    const node = createNode("trigger:webhook", [], position);
    assert.deepEqual(node.position, position);
  });

  test("createNode applies built-in defaults for webhook trigger", function (assert) {
    const node = createNode("trigger:webhook", []);
    assert.true("http_method" in node.configuration);
    assert.true("path" in node.configuration);
  });

  test("createNode applies built-in defaults for schedule trigger", function (assert) {
    const node = createNode("trigger:schedule", []);
    assert.deepEqual(node.configuration.rule, {
      interval: [{ field: "hours", hoursInterval: 1, triggerAtMinute: 0 }],
    });
  });

  test("createNode merges configOverrides over defaults", function (assert) {
    const node = createNode("trigger:webhook", [], null, {
      configOverrides: { http_method: "POST", custom_key: "custom_value" },
    });
    assert.strictEqual(node.configuration.http_method, "POST");
    assert.strictEqual(node.configuration.custom_key, "custom_value");
  });

  test("createNode accepts typeVersion override", function (assert) {
    const node = createNode("trigger:webhook", [], null, {
      typeVersion: "2.0",
    });
    assert.strictEqual(node.typeVersion, "2.0");
  });

  test("WorkflowNode.serialize splits parameters, credentials, direct settings, and webhookId", function (assert) {
    const node = WorkflowNode.create({
      type: FORM_TRIGGER_TYPE,
      typeVersion: "1.0",
      name: "Signup",
      webhookId: "form-uuid",
      configuration: {
        form_title: "Signup",
        authentication: "basic_auth",
        credentials: {
          auth: {
            id: "42",
            credential_type: "basic_auth",
          },
        },
        notes: "Shown on canvas",
        notesInFlow: true,
        alwaysOutputData: true,
      },
    });

    const serialized = WorkflowNode.serialize(node);

    assert.deepEqual(serialized.parameters, {
      form_title: "Signup",
      authentication: "basic_auth",
    });
    assert.deepEqual(serialized.credentials, {
      auth: {
        id: "42",
        credential_type: "basic_auth",
      },
    });
    assert.false("settings" in serialized);
    assert.strictEqual(serialized.notes, "Shown on canvas");
    assert.true(serialized.notesInFlow);
    assert.true(serialized.alwaysOutputData);
    assert.strictEqual(serialized.webhookId, "form-uuid");
  });

  test("WorkflowNode.serialize can explicitly clear credentials", function (assert) {
    const node = WorkflowNode.create({
      type: "trigger:webhook",
      typeVersion: "1.0",
      name: "Webhook",
      parameters: {
        path: "my-hook",
        http_method: "POST",
        authentication: "basic_auth",
      },
      credentials: {
        auth: {
          id: "42",
          credential_type: "basic_auth",
        },
      },
    });

    node.configuration.authentication = "none";
    node.configuration.credentials = {};

    const serialized = WorkflowNode.serialize(node);

    assert.deepEqual(serialized.parameters, {
      path: "my-hook",
      http_method: "POST",
      authentication: "none",
    });
    assert.deepEqual(serialized.credentials, {});
  });

  test("WorkflowNode exposes saved credential slots in configuration", function (assert) {
    const node = WorkflowNode.create({
      type: "action:http_request",
      parameters: {
        authentication: "basic_auth",
      },
      credentials: {
        auth: {
          id: "42",
          credential_type: "basic_auth",
        },
      },
    });

    assert.deepEqual(node.configuration.credentials, {
      auth: {
        id: "42",
        credential_type: "basic_auth",
      },
    });
  });
});
