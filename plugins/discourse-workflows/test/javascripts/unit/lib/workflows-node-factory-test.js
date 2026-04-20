import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  createNode,
  generateNodeName,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/editor/node-factory";

module("Unit | lib | discourse-workflows | node-factory", function (hooks) {
  setupTest(hooks);

  test("generateNodeName returns a non-empty string for a valid identifier", function (assert) {
    const name = generateNodeName("trigger:webhook", []);
    assert.strictEqual(typeof name, "string");
    assert.true(name.length > 0);
  });

  test("generateNodeName appends counter on single name collision", function (assert) {
    const baseName = generateNodeName("trigger:webhook", []);
    const existingNodes = [{ name: baseName }];
    const name = generateNodeName("trigger:webhook", existingNodes);
    assert.strictEqual(name, `${baseName} 1`);
  });

  test("generateNodeName increments counter past multiple collisions", function (assert) {
    const baseName = generateNodeName("trigger:webhook", []);
    const existingNodes = [
      { name: baseName },
      { name: `${baseName} 1` },
      { name: `${baseName} 2` },
    ];
    const name = generateNodeName("trigger:webhook", existingNodes);
    assert.strictEqual(name, `${baseName} 3`);
  });

  test("createNode returns a node with correct type and default version", function (assert) {
    const node = createNode("trigger:webhook", []);
    assert.strictEqual(node.type, "trigger:webhook");
    assert.strictEqual(node.type_version, "1.0");
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
    assert.deepEqual(node.configuration.rules, [
      { interval: "hours", hours_between_triggers: 1, trigger_at_minute: 0 },
    ]);
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
    assert.strictEqual(node.type_version, "2.0");
  });
});
