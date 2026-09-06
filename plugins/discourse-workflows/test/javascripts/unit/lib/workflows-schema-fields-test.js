import { module, test } from "qunit";
import {
  fieldsForSchema,
  schemaFieldsForItems,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/schema-fields";

module("Unit | lib | discourse-workflows | schema-fields", function () {
  test("fieldsForSchema converts JSON Schemas into draggable fields", function (assert) {
    const fields = fieldsForSchema({
      type: "object",
      properties: {
        topic: {
          type: "object",
          description: "Topic serializer payload",
          properties: {
            created_at: { type: "string", format: "date-time" },
            score: { type: ["number", "null"] },
            tags: { type: "array", items: { type: "string" } },
            groups: {
              type: "array",
              items: {
                type: "object",
                properties: { id: { type: "integer" } },
              },
            },
          },
        },
        action: { type: "string", const: "added" },
      },
    });
    const topic = fields.find((field) => field.key === "topic");
    const createdAt = topic.children.find(
      (field) => field.key === "created_at"
    );
    const score = topic.children.find((field) => field.key === "score");
    const tags = topic.children.find((field) => field.key === "tags");
    const groups = topic.children.find((field) => field.key === "groups");
    const action = fields.find((field) => field.key === "action");

    assert.strictEqual(topic.type, "object", "descriptive roots are objects");
    assert.strictEqual(
      topic.description,
      "Topic serializer payload",
      "preserves descriptions"
    );
    assert.deepEqual(
      [createdAt.type, createdAt.format, createdAt.id],
      ["string", "date-time", "$json.topic.created_at"],
      "preserves formats"
    );
    assert.deepEqual(
      [score.type, score.nullable],
      ["number", true],
      "normalizes nullable type arrays"
    );
    assert.deepEqual(
      [tags.type, tags.children[0].type, tags.children[0].id],
      ["array", "string", "$json.topic.tags[0]"],
      "adds a typed array item path at index 0"
    );
    assert.deepEqual(
      [
        groups.children[0].type,
        groups.children[0].children[0].type,
        groups.children[0].children[0].id,
      ],
      ["object", "integer", "$json.topic.groups[0].id"],
      "adds draggable paths for object array fields"
    );
    assert.deepEqual(
      [action.type, action.value, action.id],
      ["string", "added", "$json.action"],
      "preserves literal types"
    );
  });

  test("fieldsForSchema only traverses schema properties", function (assert) {
    assert.deepEqual(
      fieldsForSchema({ declared: "string" }),
      [],
      "flat maps that are not JSON Schema produce no fields"
    );
    assert.deepEqual(
      fieldsForSchema({ type: "string" }),
      [],
      "non-object schemas produce no fields"
    );
  });

  test("fieldsForSchema does not narrow conflicting type unions", function (assert) {
    const fields = fieldsForSchema({
      type: "object",
      properties: {
        conflict: { type: ["string", "integer"] },
        numeric: { type: ["integer", "number", "null"] },
        nullableInteger: { type: ["integer", "null"] },
        nullableString: { type: ["string", "null"] },
      },
    });

    assert.deepEqual(
      fields.map((field) => [field.key, field.type, field.nullable]),
      [
        ["conflict", "unknown", undefined],
        ["numeric", "number", true],
        ["nullableInteger", "integer", true],
        ["nullableString", "string", true],
      ],
      "keeps conflicts unknown while canonicalizing compatible numeric types"
    );
  });

  test("fieldsForSchema merges anyOf branches for display", function (assert) {
    const fields = fieldsForSchema({
      anyOf: [
        {
          type: "object",
          properties: {
            id: { type: "integer" },
            title: { type: "string" },
            subtitle: { anyOf: [{ type: "string" }, { type: "null" }] },
          },
        },
        {
          type: "object",
          properties: {
            id: { type: "string" },
            deleted: { type: "boolean" },
          },
        },
      ],
    });

    assert.deepEqual(
      fields.map((field) => field.key),
      ["id", "title", "subtitle", "deleted"],
      "unions properties from every branch"
    );
    assert.strictEqual(
      fields.find((field) => field.key === "id").type,
      "unknown",
      "conflicting branch types stay unknown"
    );
    assert.deepEqual(
      fields
        .filter((field) => ["title", "deleted"].includes(field.key))
        .map((field) => field.type),
      ["string", "boolean"],
      "branch-specific properties keep their own types"
    );
    assert.deepEqual(
      [
        fields.find((field) => field.key === "subtitle").type,
        fields.find((field) => field.key === "subtitle").nullable,
      ],
      ["string", true],
      "nested anyOf with a null branch becomes nullable"
    );
  });

  test("fieldsForSchema infers types from const values", function (assert) {
    const fields = fieldsForSchema({
      type: "object",
      properties: {
        action: { const: "added" },
        count: { const: 3 },
        flag: { const: true },
      },
    });

    assert.deepEqual(
      fields.map((field) => [field.key, field.type, field.value]),
      [
        ["action", "string", "added"],
        ["count", "integer", 3],
        ["flag", "boolean", true],
      ],
      "const provides both the value and the inferred type"
    );
  });

  test("fieldsForSchema uses bracket paths for unsafe keys", function (assert) {
    const fields = fieldsForSchema({
      type: "object",
      properties: {
        "topic title": {
          type: "object",
          properties: {
            "post-count": { type: "integer" },
          },
        },
      },
    });

    assert.strictEqual(fields[0].id, '$json["topic title"]');
    assert.strictEqual(
      fields[0].children[0].id,
      '$json["topic title"]["post-count"]'
    );
  });

  test("fieldsForSchema honors the prefix option", function (assert) {
    const fields = fieldsForSchema(
      {
        type: "object",
        properties: { title: { type: "string" } },
      },
      { prefix: "$item" }
    );

    assert.strictEqual(fields[0].id, "$item.title");
  });

  test("schemaFieldsForItems infers and merges nested JSON fields", function (assert) {
    const fields = schemaFieldsForItems([
      {
        json: {
          title: "Hello",
          count: 1,
          published: true,
          author: { username: "sam" },
        },
      },
      {
        json: {
          count: 2,
          author: { id: 12 },
          tags: ["support"],
        },
      },
    ]);

    assert.deepEqual(
      fields.map((field) => [field.key, field.type, field.id]),
      [
        ["title", "string", "$json.title"],
        ["count", "number", "$json.count"],
        ["published", "boolean", "$json.published"],
        ["author", "object", "$json.author"],
        ["tags", "array", "$json.tags"],
      ]
    );
    assert.deepEqual(
      fields.find((field) => field.key === "author").children.map((f) => f.key),
      ["username", "id"]
    );
    assert.strictEqual(
      fields.find((field) => field.key === "tags").children[0].id,
      "$json.tags[0]"
    );
  });

  test("schemaFieldsForItems uses bracket paths for unsafe keys", function (assert) {
    const fields = schemaFieldsForItems([
      { json: { "topic title": { "post-count": 2 } } },
    ]);

    assert.strictEqual(fields[0].id, '$json["topic title"]');
    assert.strictEqual(
      fields[0].children[0].id,
      '$json["topic title"]["post-count"]'
    );
  });

  test("schemaFieldsForItems preserves null values", function (assert) {
    const fields = schemaFieldsForItems([
      { json: { deleted_at: null, title: null } },
      { json: { title: "Topic" } },
    ]);

    const deletedAt = fields.find((field) => field.key === "deleted_at");
    const title = fields.find((field) => field.key === "title");

    assert.strictEqual(deletedAt.type, "null");
    assert.strictEqual(deletedAt.value, null);
    assert.strictEqual(title.type, "string");
    assert.strictEqual(title.value, "Topic");
  });
});
