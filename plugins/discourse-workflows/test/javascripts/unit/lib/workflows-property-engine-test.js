import { module, test } from "qunit";
import { normalizeCodeEditorValue } from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/code-control";
import {
  collectionAddLabel,
  emptyCollectionItem,
  fieldControl,
  fieldFormat,
  fieldSupportsExpression,
  fieldValue,
  fieldVisible,
  getPropertySchema,
  i18nPrefix,
  i18nScope,
  localeKeyPart,
  normalizeOptions,
  propertyDescription,
  propertyDynamicValueHint,
  propertyLabel,
  propertyOptionLabel,
  propertyPlaceholder,
  propertySelectNoneKey,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/property-engine";

module("Unit | Utility | workflows property engine", function () {
  const ifNodeType = {
    identifier: "condition:if",
    ui: { i18n_scope: "if" },
  };
  const dataTableNodeType = {
    identifier: "action:data_table",
    ui: { i18n_scope: "data_table_node" },
  };

  test("derives the translation scope from the node identifier", function (assert) {
    assert.strictEqual(i18nScope("action:topic"), "topic");
    assert.strictEqual(i18nScope(dataTableNodeType), "data_table_node");
  });

  test("resolves translated labels, descriptions, and placeholders", function (assert) {
    assert.strictEqual(propertyLabel("action:topic", "title"), "Title");
    assert.strictEqual(propertyLabel(ifNodeType, "combinator"), "Match mode");
    assert.strictEqual(
      propertyLabel("trigger:schedule", "minutesInterval"),
      "Minutes between triggers"
    );
    assert.strictEqual(propertyLabel("header_auth", "name"), "Header name");
    assert.strictEqual(propertyLabel("header_auth", "value"), "Header value");
    assert.strictEqual(
      propertyDescription("action:topic", "raw"),
      "Raw content for the first post"
    );
    assert.strictEqual(
      propertyDescription("action:code", "code"),
      "Access the previous step's output via $json. Return an object to pass data to the next step."
    );
    assert.strictEqual(
      propertyDescription("trigger:schedule", "minutesInterval"),
      "Must be in range 1-59"
    );
    assert.strictEqual(
      propertyPlaceholder("trigger:webhook", "path"),
      "my-webhook"
    );
    assert.strictEqual(
      propertyPlaceholder("trigger:reviewable_approved", "reviewable_types"),
      "All types"
    );
  });

  test("falls back to the shared property_engine.fields scope", function (assert) {
    assert.strictEqual(
      propertyLabel("trigger:topic_created", "category_ids"),
      "Categories"
    );
    assert.strictEqual(
      propertyDescription("trigger:topic_created", "category_ids"),
      "Only trigger for topics in these categories. Leave empty to match all categories."
    );
    assert.strictEqual(
      propertyPlaceholder("trigger:topic_closed", "category_ids"),
      "All categories"
    );
    assert.strictEqual(
      propertyLabel("trigger:topic_tag_changed", "include_subcategories"),
      "Include subcategories"
    );

    // node-scoped keys win over the shared scope
    assert.strictEqual(
      propertyLabel("trigger:post_moved", "category_ids"),
      "Destination categories"
    );
    assert.strictEqual(
      propertyDescription("trigger:stale_topic", "category_ids"),
      "Only consider topics in these categories. Leave empty to match all categories."
    );
  });

  test("resolves dynamic value hints for expression fields", function (assert) {
    assert.strictEqual(
      propertyDynamicValueHint("action:topic", "category_id", {
        type: "integer",
        ui: { control: "category" },
      }),
      "Must resolve to a category ID."
    );
    assert.strictEqual(
      propertyDynamicValueHint("action:badge", "badge_id", {
        type: "integer",
        ui: { control: "combo_box", dynamic_value: "badge_id" },
      }),
      "Must resolve to a badge ID."
    );
    assert.strictEqual(
      propertyDynamicValueHint("action:group", "actor_username", {
        type: "string",
        ui: { control: "user" },
      }),
      "Must resolve to a username."
    );
    assert.strictEqual(
      propertyDynamicValueHint("action:group", "actor_username", {
        type: "string",
        ui: { control: "actor" },
      }),
      "Must resolve to a username."
    );
  });

  test("supports plugin translation roots", function (assert) {
    const nodeDefinition = {
      identifier: "action:ai_agent",
      ui: {
        i18n_prefix: "discourse_ai.discourse_workflows",
      },
    };

    assert.strictEqual(
      i18nPrefix(nodeDefinition),
      "discourse_ai.discourse_workflows"
    );
    assert.strictEqual(propertyLabel(nodeDefinition, "agent_id"), "Agent");
    assert.strictEqual(
      propertySelectNoneKey(nodeDefinition, "agent_id"),
      "discourse_ai.discourse_workflows.ai_agent.select_agent"
    );
  });

  test("gets property schema from the saved node type version", function (assert) {
    const nodeTypes = [
      {
        identifier: "action:versioned",
        latest: {
          properties: {
            new_field: { type: "string" },
          },
        },
        versions: {
          "1.0": {
            properties: {
              old_field: { type: "string" },
            },
          },
          "2.0": {
            properties: {
              new_field: { type: "string" },
            },
          },
        },
      },
    ];

    assert.deepEqual(getPropertySchema(nodeTypes, "action:versioned", "1.0"), {
      old_field: { type: "string" },
    });
    assert.deepEqual(getPropertySchema(nodeTypes, "action:versioned"), {
      new_field: { type: "string" },
    });
  });

  test("normalizes options and option labels", function (assert) {
    const options = normalizeOptions(["GET", { value: "deny" }]);

    assert.deepEqual(options, [{ value: "GET" }, { value: "deny" }]);
    assert.strictEqual(
      propertyOptionLabel("flow:wait", "resume", {
        value: "webhook",
      }),
      "On webhook call"
    );
    assert.strictEqual(
      propertyOptionLabel("action:http_request", "method", { value: "GET" }),
      "GET"
    );
    assert.strictEqual(
      propertyOptionLabel(dataTableNodeType, "operation", {
        value: "insert",
      }),
      "Insert"
    );
    assert.strictEqual(
      propertyOptionLabel("action:code", "mode", {
        value: "runOnceForEachItem",
      }),
      "Run once for each item"
    );
    assert.strictEqual(
      propertyOptionLabel("trigger:schedule", "field", {
        value: "cronExpression",
      }),
      "Custom (Cron)"
    );
    assert.strictEqual(
      propertyOptionLabel("trigger:post_edited", "trust_levels", {
        value: "0",
        label_key: "trust_levels.names.newuser",
      }),
      "new user"
    );
  });

  test("normalizes camelCase values for locale key lookup", function (assert) {
    assert.strictEqual(localeKeyPart("fooBarBaz"), "foo_bar_baz");
    assert.strictEqual(localeKeyPart("cronExpression"), "cron_expression");
    assert.strictEqual(
      localeKeyPart("runOnceForAllItems"),
      "run_once_for_all_items"
    );
  });

  test("uses defaults and sensible fallbacks for field values", function (assert) {
    assert.strictEqual(fieldValue({ type: "string", default: "GET" }), "GET");
    assert.false(fieldValue({ type: "boolean" }));
    assert.deepEqual(fieldValue({ type: "collection" }), {});
    assert.deepEqual(fieldValue({ type: "fixed_collection" }), {});
    assert.deepEqual(fieldValue({ type: "assignment_collection" }), {
      assignments: [],
    });
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
    assert.strictEqual(
      fieldControl({ type: "multi_options" }),
      "multi_combo_box"
    );
    assert.strictEqual(fieldControl({ type: "collection" }), "collection");
    assert.strictEqual(
      fieldControl({ type: "fixed_collection" }),
      "fixed_collection"
    );
    assert.strictEqual(
      fieldControl({ type: "assignment_collection" }),
      "assignment_collection"
    );
    assert.strictEqual(fieldControl({ type: "fixedCollection" }), "input");
    assert.strictEqual(fieldFormat({ type: "string" }), "full");
    assert.strictEqual(
      fieldFormat({ type: "string", ui: { format: "small" } }),
      "small"
    );
    assert.true(fieldSupportsExpression({ type: "integer" }));
    assert.true(fieldSupportsExpression({ type: "icon" }));
    assert.false(fieldSupportsExpression({ type: "multi_options" }));
    assert.false(
      fieldSupportsExpression({ type: "string", no_data_expression: true })
    );
    assert.true(
      fieldSupportsExpression({ type: "options", ui: { expression: true } })
    );
  });

  test("multi_options defaults to an empty array", function (assert) {
    assert.deepEqual(fieldValue({ type: "multi_options" }), []);
    assert.deepEqual(
      fieldValue({ type: "multi_options", default: [1, 2] }),
      [1, 2]
    );
  });

  test("evaluates simple visibility rules against the current configuration", function (assert) {
    const schema = {
      type: "string",
      display_options: {
        show: {
          method: ["POST", "PUT"],
        },
      },
    };

    assert.true(fieldVisible(schema, { method: "POST" }));
    assert.false(fieldVisible(schema, { method: "GET" }));
    assert.false(fieldVisible({ type: "string", ui: { hidden: true } }, {}));
  });

  test("supports the exists condition for empty checks", function (assert) {
    const schema = {
      type: "notice",
      display_options: { hide: { columns: [{ condition: { exists: true } }] } },
    };

    assert.true(fieldVisible(schema, {}));
    assert.true(fieldVisible(schema, { columns: null }));
    assert.true(fieldVisible(schema, { columns: [] }));
    assert.true(fieldVisible(schema, { columns: "" }));
    assert.false(fieldVisible(schema, { columns: [{ header: "A" }] }));
    assert.false(fieldVisible(schema, { columns: "value" }));

    const presentSchema = {
      display_options: { show: { columns: [{ condition: { exists: true } }] } },
    };
    assert.false(fieldVisible(presentSchema, {}));
    assert.true(fieldVisible(presentSchema, { columns: [{ header: "A" }] }));
  });

  test("supports the not condition", function (assert) {
    const schema = {
      display_options: {
        show: { operation: [{ condition: { not: "delete" } }] },
      },
    };
    assert.true(fieldVisible(schema, { operation: "insert" }));
    assert.true(fieldVisible(schema, {}));
    assert.false(fieldVisible(schema, { operation: "delete" }));
  });

  test("display_options.hide hides a field when its rules match", function (assert) {
    const schema = { display_options: { hide: { method: ["GET", "HEAD"] } } };
    assert.false(fieldVisible(schema, { method: "GET" }));
    assert.true(fieldVisible(schema, { method: "POST" }));

    const combined = {
      display_options: {
        show: { method: ["POST", "PUT", "PATCH"] },
        hide: { content_type: "raw" },
      },
    };
    assert.true(
      fieldVisible(combined, { method: "POST", content_type: "json" })
    );
    assert.false(
      fieldVisible(combined, { method: "GET", content_type: "json" })
    );
    assert.false(
      fieldVisible(combined, { method: "POST", content_type: "raw" })
    );
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
      collectionAddLabel("action:topic", "attachments"),
      "Add item"
    );
  });

  test("lets ui.singular_name override the derived singular", function (assert) {
    assert.strictEqual(
      collectionAddLabel("action:http_request", "attachments", {
        ui: { singular_name: "header" },
      }),
      "Add header"
    );
    assert.strictEqual(
      collectionAddLabel("action:http_request", "attachments"),
      "Add item"
    );
  });

  test("normalizes object values for JSON code controls", function (assert) {
    assert.strictEqual(
      normalizeCodeEditorValue({ "x-broccoli": { enabled: true } }, "json"),
      '{\n  "x-broccoli": {\n    "enabled": true\n  }\n}'
    );
    assert.strictEqual(
      normalizeCodeEditorValue(["alpha", "beta"], "json"),
      '[\n  "alpha",\n  "beta"\n]'
    );
    assert.strictEqual(normalizeCodeEditorValue("plain", "json"), "plain");
  });
});
