import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import categoryStyleType from "discourse/lib/category-style-type";
import { helperContext } from "discourse/lib/helpers";

module("Unit | Lib | category-style-type", function (hooks) {
  setupTest(hooks);

  test("keeps the saved style", function (assert) {
    helperContext().siteSettings.enable_emoji = true;

    assert.strictEqual(categoryStyleType("icon"), "icon");
    assert.strictEqual(categoryStyleType("emoji"), "emoji");
    assert.strictEqual(categoryStyleType(undefined), undefined);
  });

  test("falls back to square for emoji while emoji are disabled", function (assert) {
    helperContext().siteSettings.enable_emoji = false;

    assert.strictEqual(categoryStyleType("emoji"), "square");
    assert.strictEqual(
      categoryStyleType("icon"),
      "icon",
      "other styles are kept"
    );
  });
});
