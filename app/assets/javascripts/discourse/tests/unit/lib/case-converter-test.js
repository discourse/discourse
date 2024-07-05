import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  camelCaseToDash,
  camelCaseToSnakeCase,
  snakeCaseToCamelCase,
} from "discourse-common/lib/case-converter";

module("Unit | discourse-common | case-converter", function (hooks) {
  setupTest(hooks);

  test("camelCaseToSnakeCase", function (assert) {
    assert.equal(camelCaseToSnakeCase("camelCase"), "camel_case");
    assert.equal(camelCaseToSnakeCase("camelCase99"), "camel_case99");
    assert.equal(camelCaseToSnakeCase("camelCaseId"), "camel_case_id");
    assert.equal(camelCaseToSnakeCase("camelCaseUrl"), "camel_case_url");
  });

  test("camelCaseToDash", function (assert) {
    assert.equal(camelCaseToDash("camelCase"), "camel-case");
    assert.equal(camelCaseToDash("camelCaseToDash99"), "camel-case-to-dash99");
    assert.equal(camelCaseToDash("camelCaseId"), "camel-case-id");
    assert.equal(camelCaseToDash("camelCaseUrl"), "camel-case-url");
  });

  test("snakeCaseToCamelCase", function (assert) {
    assert.equal(snakeCaseToCamelCase("snake_case"), "snakeCase");
    assert.equal(snakeCaseToCamelCase("snake_case99"), "snakeCase99");
    assert.equal(snakeCaseToCamelCase("some_id"), "someId");
    assert.equal(snakeCaseToCamelCase("some_url"), "someUrl");
  });
});
