import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import categoryVariables from "discourse/helpers/category-variables";

module("Unit | Helper | category-variables", function (hooks) {
  setupTest(hooks);

  test("sets the badge colors", function (assert) {
    assert.strictEqual(
      categoryVariables({ color: "ff0", textColor: "f00" }).toString(),
      "--category-badge-color: #ff0;--category-badge-text-color: #f00;"
    );
  });

  test("sets the parent badge colors", function (assert) {
    assert.strictEqual(
      categoryVariables({
        parentCategory: { color: "0f0", textColor: "00f" },
      }).toString(),
      "--parent-category-badge-color: #0f0;--parent-category-badge-text-color: #00f;"
    );
  });

  test("is empty without colors", function (assert) {
    assert.strictEqual(categoryVariables({}).toString(), "");
  });
});
