import { module, test } from "qunit";
import {
  implicitValueFor,
  isSingleValueOperator,
  operatorOptionsForType,
  operatorsForType,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/condition-operators";

module("Unit | lib | discourse-workflows | condition operators", function () {
  test("returns workflow operators by canonical type", function (assert) {
    assert.deepEqual(operatorsForType("number"), [
      "equals",
      "notEquals",
      "gt",
      "lt",
      "gte",
      "lte",
    ]);
  });

  test("offers ordering operators for string values", function (assert) {
    assert.deepEqual(operatorsForType("string"), [
      "equals",
      "notEquals",
      "contains",
      "notContains",
      "empty",
      "notEmpty",
      "gt",
      "lt",
      "gte",
      "lte",
    ]);
  });

  test("builds translatable operator options", function (assert) {
    assert.deepEqual(operatorOptionsForType("boolean"), [
      {
        value: "equals",
        label_key: "discourse_workflows.if.operators.equals",
      },
      {
        value: "notEquals",
        label_key: "discourse_workflows.if.operators.not_equals",
      },
      {
        value: "true",
        label_key: "discourse_workflows.if.operators.true",
      },
      {
        value: "false",
        label_key: "discourse_workflows.if.operators.false",
      },
    ]);
  });

  test("returns data-table operators by context", function (assert) {
    assert.deepEqual(operatorsForType("boolean", { context: "data_table" }), [
      "empty",
      "notEmpty",
      "true",
      "false",
    ]);
  });

  test("exposes single-value operator metadata", function (assert) {
    assert.true(isSingleValueOperator("empty"));
    assert.false(isSingleValueOperator("equals"));
    assert.true(implicitValueFor("true"));
    assert.strictEqual(implicitValueFor("empty"), null);
  });

  test("defaults missing types to string operators", function (assert) {
    assert.deepEqual(operatorsForType(null), operatorsForType("string"));
  });
});
