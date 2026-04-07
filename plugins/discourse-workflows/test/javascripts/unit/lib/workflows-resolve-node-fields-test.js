import { module, test } from "qunit";
import resolveNodeFields, {
  fieldsFromSchema,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/resolve-node-fields";

module("Unit | lib | discourse-workflows | resolve-node-fields", function () {
  test("fieldsFromSchema converts flat output schema to field entries", function (assert) {
    const schema = { topic_id: "integer", title: "string" };
    const fields = fieldsFromSchema(schema);

    assert.strictEqual(fields.length, 2);
    assert.deepEqual(fields[0], {
      key: "topic_id",
      type: "integer",
      id: "topic_id",
    });
    assert.deepEqual(fields[1], {
      key: "title",
      type: "string",
      id: "title",
    });
  });

  test("fieldsFromSchema converts nested object schema", function (assert) {
    const schema = {
      body: { topic_id: "integer", title: "string" },
    };
    const fields = fieldsFromSchema(schema);

    assert.strictEqual(fields.length, 1);
    assert.strictEqual(fields[0].key, "body");
    assert.strictEqual(fields[0].type, "object");
    assert.strictEqual(fields[0].children.length, 2);
  });

  test("fieldsFromSchema returns null for empty schema", function (assert) {
    assert.strictEqual(fieldsFromSchema({}), null);
    assert.strictEqual(fieldsFromSchema(null), null);
  });

  test("resolveNodeFields uses config output_fields first", function (assert) {
    const node = {
      type: "action:http_request",
      configuration: {
        output_fields: [{ key: "response", type: "object" }],
      },
    };
    const fields = resolveNodeFields(node, []);

    assert.strictEqual(fields.length, 1);
    assert.strictEqual(fields[0].key, "response");
  });

  test("resolveNodeFields falls back to output_schema from node type", function (assert) {
    const node = { type: "trigger:webhook", configuration: {} };
    const nodeTypes = [
      {
        identifier: "trigger:webhook",
        output_schema: { body: "object", method: "string" },
      },
    ];
    const fields = resolveNodeFields(node, nodeTypes);

    assert.strictEqual(fields.length, 2);
    assert.strictEqual(fields[0].key, "body");
  });

  test("resolveNodeFields filters fields by visible_if", function (assert) {
    const node = {
      type: "core:wait",
      configuration: { resume: "webhook" },
    };
    const nodeTypes = [
      {
        identifier: "core:wait",
        output_schema: {
          body: { type: "object", visible_if: { resume: "webhook" } },
          hidden: {
            type: "string",
            visible_if: { resume: "something_else" },
          },
        },
      },
    ];
    const fields = resolveNodeFields(node, nodeTypes);

    assert.strictEqual(fields.length, 1);
    assert.strictEqual(fields[0].key, "body");
  });

  test("resolveNodeFields returns null for node with no schema", function (assert) {
    const node = { type: "core:code", configuration: {} };
    const fields = resolveNodeFields(node, []);

    assert.strictEqual(fields, null);
  });
});
