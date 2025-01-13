import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  camelCaseToDash,
  camelCaseToSnakeCase,
  snakeCaseToCamelCase,
} from "discourse/lib/case-converter";

module("Unit | discourse | case-converter", function (hooks) {
  setupTest(hooks);

  test("camelCaseToSnakeCase", function (assert) {
    assert.strictEqual(camelCaseToSnakeCase("camelCase"), "camel_case");
    assert.strictEqual(camelCaseToSnakeCase("camelCase99"), "camel_case99");
    assert.strictEqual(camelCaseToSnakeCase("camelCaseId"), "camel_case_id");
    assert.strictEqual(camelCaseToSnakeCase("camelCaseUrl"), "camel_case_url");
  });

  test("camelCaseToDash", function (assert) {
    assert.strictEqual(camelCaseToDash("camelCase"), "camel-case");
    assert.strictEqual(
      camelCaseToDash("camelCaseToDash99"),
      "camel-case-to-dash99"
    );
    assert.strictEqual(camelCaseToDash("camelCaseId"), "camel-case-id");
    assert.strictEqual(camelCaseToDash("camelCaseUrl"), "camel-case-url");
  });

  test("snakeCaseToCamelCase", function (assert) {
    assert.strictEqual(snakeCaseToCamelCase("snake_case"), "snakeCase");
    assert.strictEqual(snakeCaseToCamelCase("snake_case99"), "snakeCase99");
    assert.strictEqual(snakeCaseToCamelCase("some_id"), "someId");
    assert.strictEqual(snakeCaseToCamelCase("some_url"), "someUrl");
  });
});
