import { module, test } from "qunit";
import {
  propertyAccessor,
  referencePickerData,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-extensions/reference-properties";

module("Unit | lib | discourse-workflows | propertyAccessor", function () {
  test("uses dotted access for plain identifiers", function (assert) {
    assert.strictEqual(propertyAccessor("topic"), ".topic");
    assert.strictEqual(propertyAccessor("topic_id"), ".topic_id");
    assert.strictEqual(propertyAccessor("$ref"), ".$ref");
    assert.strictEqual(propertyAccessor("_private"), "._private");
  });

  test("uses quoted bracket access for non-identifier names", function (assert) {
    assert.strictEqual(propertyAccessor("product-name"), '["product-name"]');
    assert.strictEqual(propertyAccessor("order id"), '["order id"]');
    assert.strictEqual(propertyAccessor("123"), '["123"]');
    assert.strictEqual(propertyAccessor("a.b"), '["a.b"]');
  });

  test("escapes quotes and backslashes in bracket access", function (assert) {
    assert.strictEqual(propertyAccessor('we"ird'), '["we\\"ird"]');
    assert.strictEqual(propertyAccessor("back\\slash"), '["back\\\\slash"]');
  });
});

module("Unit | lib | discourse-workflows | referencePickerData", function () {
  const scope = {
    $vars: {
      topic: { id: 123, title: "Hello", "a.b": "dotted-key" },
    },
  };

  test("drills into an object reference", function (assert) {
    const data = referencePickerData(scope, "$vars.topic");
    assert.strictEqual(data.baseExpr, "$vars.topic");
    assert.strictEqual(data.current, null);
    assert.true(data.properties.some((p) => p.name === "id"));
  });

  test("switches siblings for a leaf reference", function (assert) {
    const data = referencePickerData(scope, "$vars.topic.title");
    assert.strictEqual(data.baseExpr, "$vars.topic");
    assert.strictEqual(data.current, "title");
  });

  test("splits on the last top-level accessor, not a dot inside a bracket key", function (assert) {
    const data = referencePickerData(scope, '$vars.topic["a.b"]');
    assert.strictEqual(data.baseExpr, "$vars.topic");
    assert.strictEqual(data.current, "a.b");
    assert.true(data.properties.some((p) => p.name === "a.b"));
  });

  test("returns null when nothing can be picked", function (assert) {
    assert.strictEqual(referencePickerData(scope, ""), null);
    // No accessor and no resolvable object: nothing to drill or switch.
    assert.strictEqual(referencePickerData(scope, "unknownRoot"), null);
  });
});
