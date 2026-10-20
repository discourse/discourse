import { module, test } from "qunit";
import { fieldValidator } from "discourse/plugins/discourse-workflows/admin/lib/workflows/field-validators";

function errorsFor(schema, value) {
  const errors = [];
  fieldValidator(schema, "Title")("field", value, {
    addError: (name, error) => errors.push({ name, ...error }),
  });
  return errors;
}

module("Unit | lib | discourse-workflows | field-validators", function () {
  test("returns undefined for an unknown validator", function (assert) {
    assert.strictEqual(
      fieldValidator({ validate: "nope" }, "Title"),
      undefined
    );
    assert.strictEqual(fieldValidator({}, "Title"), undefined);
    assert.strictEqual(fieldValidator(undefined, "Title"), undefined);
  });

  test("cron flags invalid expressions only", function (assert) {
    const cron = { validate: "cron" };

    assert.strictEqual(errorsFor(cron, "bad").length, 1);
    assert.strictEqual(errorsFor(cron, "*/5 * * * *").length, 0);
    assert.strictEqual(errorsFor(cron, "={{ $json.cron }}").length, 0);
    assert.strictEqual(errorsFor(cron, "").length, 0);
  });

  test("non_empty_expression flags blank expressions only", function (assert) {
    const schema = { validate: "non_empty_expression" };

    const [error] = errorsFor(schema, "={{ }}");
    assert.strictEqual(error.name, "field");
    assert.strictEqual(error.title, "Title", "uses the field title");
    assert.strictEqual(errorsFor(schema, "={{ x }}").length, 0);
  });
});
