import { module, test } from "qunit";
import {
  collectionAddLabel,
  emptyCollectionItem,
  fieldControl,
  fieldFormat,
  fieldSupportsExpression,
  fieldValue,
  fieldVisible,
  normalizeOptions,
  propertyDescription,
  propertyI18nPrefix,
  propertyLabel,
  propertyOptionLabel,
  propertyPlaceholder,
  propertyScope,
  propertySelectNoneKey,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/property-engine";

module("Unit | Utility | workflows property engine", function () {
  test("derives the translation scope from the node identifier", function (assert) {
    assert.strictEqual(propertyScope("action:create_topic"), "create_topic");
    assert.strictEqual(propertyScope("action:data_table"), "data_table_node");
  });

  test("resolves translated labels, descriptions, and placeholders", function (assert) {
    assert.strictEqual(propertyLabel("action:create_topic", "title"), "Title");
    assert.strictEqual(
      propertyLabel("condition:if", "combinator"),
      "Match mode"
    );
    assert.strictEqual(
      propertyDescription("action:create_topic", "raw"),
      "Raw content for the first post."
    );
    assert.strictEqual(
      propertyDescription("action:code", "code"),
      "Access the previous step's output via $json. Return an object to pass data to the next step."
    );
    assert.strictEqual(
      propertyPlaceholder("trigger:webhook", "path"),
      "my-webhook"
    );
  });

  test("supports plugin translation roots", function (assert) {
    const nodeDefinition = {
      identifier: "action:ai_agent",
      metadata: {
        i18n_prefix: "discourse_ai.discourse_workflows",
      },
    };

    assert.strictEqual(
      propertyI18nPrefix(nodeDefinition),
      "discourse_ai.discourse_workflows"
    );
    assert.strictEqual(propertyLabel(nodeDefinition, "agent_id"), "Agent");
    assert.strictEqual(
      propertySelectNoneKey(nodeDefinition, "agent_id"),
      "discourse_ai.discourse_workflows.ai_agent.select_agent"
    );
  });

  test("normalizes options and option labels", function (assert) {
    const options = normalizeOptions(["GET", { value: "deny" }]);

    assert.deepEqual(options, [{ value: "GET" }, { value: "deny" }]);
    assert.strictEqual(
      propertyOptionLabel("action:chat_approval", "timeout_action", {
        value: "deny",
      }),
      "Resume as denied"
    );
    assert.strictEqual(
      propertyOptionLabel("action:http_request", "method", { value: "GET" }),
      "GET"
    );
    assert.strictEqual(
      propertyOptionLabel("action:data_table", "operation", {
        value: "insert",
      }),
      "Insert"
    );
  });

  test("uses defaults and sensible fallbacks for field values", function (assert) {
    assert.strictEqual(fieldValue({ type: "string", default: "GET" }), "GET");
    assert.false(fieldValue({ type: "boolean" }));
    assert.deepEqual(fieldValue({ type: "collection" }), []);
    assert.strictEqual(fieldValue({ type: "string" }, "custom"), "custom");
  });

  test("builds empty collection items from item schema defaults", function (assert) {
    assert.deepEqual(
      emptyCollectionItem({
        key: { type: "string" },
        enabled: { type: "boolean", default: true },
      }),
      { key: "", enabled: true }
    );
  });

  test("respects UI control and expression hints", function (assert) {
    assert.strictEqual(
      fieldControl({ type: "string", ui: { control: "textarea" } }),
      "textarea"
    );
    assert.strictEqual(fieldControl({ type: "icon" }), "icon");
    assert.strictEqual(fieldFormat({ type: "string" }), "full");
    assert.strictEqual(
      fieldFormat({ type: "string", ui: { format: "small" } }),
      "small"
    );
    assert.true(fieldSupportsExpression({ type: "integer" }));
    assert.true(fieldSupportsExpression({ type: "icon" }));
    assert.false(
      fieldSupportsExpression({ type: "string", ui: { expression: false } })
    );
    assert.true(
      fieldSupportsExpression({ type: "options", ui: { expression: true } })
    );
  });

  test("evaluates simple visibility rules against the current configuration", function (assert) {
    const schema = {
      type: "string",
      visible_if: {
        method: ["POST", "PUT"],
      },
    };

    assert.true(fieldVisible(schema, { method: "POST" }));
    assert.false(fieldVisible(schema, { method: "GET" }));
    assert.false(fieldVisible({ type: "string", ui: { hidden: true } }, {}));
  });

  test("reuses field-specific add labels before falling back to a generic one", function (assert) {
    assert.strictEqual(
      collectionAddLabel("action:http_request", "headers"),
      "Add header"
    );
    assert.strictEqual(
      collectionAddLabel("action:http_request", "query_params"),
      "Add parameter"
    );
    assert.strictEqual(
      collectionAddLabel("action:create_topic", "attachments"),
      "Add item"
    );
  });
});
