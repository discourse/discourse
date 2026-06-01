import { module, test } from "qunit";
import getNodeIssues from "discourse/plugins/discourse-workflows/admin/lib/workflows/node-issues";

module("Unit | lib | discourse-workflows | node-issues", function () {
  test("reports no issues when all required fields are set", function (assert) {
    const schema = {
      form_title: { type: "string", required: true },
    };
    const config = { form_title: "My form" };

    assert.deepEqual(getNodeIssues(config, schema), []);
  });

  test("reports a top-level required field as missing", function (assert) {
    const schema = {
      form_title: { type: "string", required: true },
    };

    const issues = getNodeIssues({}, schema);

    assert.strictEqual(issues.length, 1);
    assert.strictEqual(issues[0].path, "form_title");
    assert.strictEqual(issues[0].message, "required");
  });

  test("treats blank strings as missing", function (assert) {
    const schema = {
      form_title: { type: "string", required: true },
    };

    assert.strictEqual(getNodeIssues({ form_title: "   " }, schema).length, 1);
  });

  test("treats empty arrays as missing when required", function (assert) {
    const schema = {
      form_fields: {
        type: "fixed_collection",
        required: true,
        options: [{ name: "values", values: {} }],
      },
    };

    assert.strictEqual(
      getNodeIssues({ form_fields: { values: [] } }, schema).length,
      1
    );
  });

  test("walks fixed collection items and reports missing nested required fields", function (assert) {
    const schema = {
      form_fields: {
        type: "fixed_collection",
        options: [
          {
            name: "values",
            values: {
              field_label: { type: "string", required: true },
              field_type: { type: "options", required: true },
            },
          },
        ],
      },
    };
    const config = {
      form_fields: {
        values: [
          { field_label: "", field_type: "text" },
          { field_label: "Name", field_type: "" },
        ],
      },
    };

    const issues = getNodeIssues(config, schema);

    assert.deepEqual(issues.map((i) => i.path).sort(), [
      "form_fields.values.0.field_label",
      "form_fields.values.1.field_type",
    ]);
  });

  test("respects display_options show rules — hidden required fields are not reported", function (assert) {
    const schema = {
      page_type: { type: "options", default: "page" },
      completion_title: {
        type: "string",
        required: true,
        display_options: { show: { page_type: ["completion"] } },
      },
    };

    assert.deepEqual(getNodeIssues({ page_type: "page" }, schema), []);

    assert.strictEqual(
      getNodeIssues({ page_type: "completion" }, schema).length,
      1
    );
  });

  test("walks optional fields inside fixed collections", function (assert) {
    const schema = {
      form_fields: {
        type: "fixed_collection",
        options: [
          {
            name: "values",
            values: {
              field_label: { type: "string", required: true },
              field_name: { type: "string" },
              custom_required: { type: "string", required: true },
            },
          },
        ],
      },
    };

    const issues = getNodeIssues(
      { form_fields: { values: [{ field_label: "Name" }] } },
      schema
    );

    assert.deepEqual(
      issues.map((i) => i.path),
      ["form_fields.values.0.custom_required"]
    );
  });

  test("returns empty array when schema is missing", function (assert) {
    assert.deepEqual(getNodeIssues({}, null), []);
    assert.deepEqual(getNodeIssues({}, undefined), []);
  });

  test("applies field defaults before checking required", function (assert) {
    const schema = {
      operation: { type: "options", required: true, default: "add" },
    };

    assert.deepEqual(getNodeIssues({}, schema), []);
  });
});
