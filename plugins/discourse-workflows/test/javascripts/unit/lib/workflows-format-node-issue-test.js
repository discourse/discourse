import { module, test } from "qunit";
import formatNodeIssue from "discourse/plugins/discourse-workflows/admin/lib/workflows/format-node-issue";

module("Unit | lib | discourse-workflows | format-node-issue", function () {
  const nodeType = {
    identifier: "action:test",
    metadata: { i18n_prefix: "discourse_workflows", i18n_scope: "test_node" },
  };

  test("formats a required-message with the property's localized label", function (assert) {
    const formatted = formatNodeIssue(
      { path: "code", name: "code", message: "required" },
      nodeType
    );

    assert.strictEqual(formatted, "Code is required");
  });

  test("falls back to a generic message for unknown issue types", function (assert) {
    const formatted = formatNodeIssue(
      { path: "code", name: "code", message: "out_of_range" },
      nodeType
    );

    assert.strictEqual(formatted, "Code: out_of_range");
  });
});
