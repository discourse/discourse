import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ValidationParser from "discourse/form-kit/lib/validation-parser";

module("Unit | Lib | FormKit | ValidationParser", function (hooks) {
  setupTest(hooks);

  test("combining rules", function (assert) {
    const rules = ValidationParser.parse("required|url");

    assert.deepEqual(rules.required, { trim: false });
    assert.deepEqual(rules.url, {});
  });

  test("unknown rule", function (assert) {
    assert.throws(() => ValidationParser.parse("foo"), "Unknown rule: foo");
  });

  test("required", function (assert) {
    const rules = ValidationParser.parse("required");

    assert.deepEqual(rules.required, { trim: false });
  });

  test("url", function (assert) {
    const rules = ValidationParser.parse("url");

    assert.deepEqual(rules.url, {});
  });

  test("accepted", function (assert) {
    const rules = ValidationParser.parse("accepted");

    assert.deepEqual(rules.accepted, {});
  });

  test("number", function (assert) {
    const rules = ValidationParser.parse("number");

    assert.deepEqual(rules.number, {});
  });

  test("length", function (assert) {
    assert.throws(
      () => ValidationParser.parse("length"),
      "`length` rule expects min/max, eg: length:1,10"
    );

    const rules = ValidationParser.parse("length:1,10");

    assert.deepEqual(rules.length, { min: 1, max: 10 });
  });
});
