import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { ExtraNavItem } from "discourse/models/nav-item";

module("Unit | Model | extra-nav-item", function (hooks) {
  setupTest(hooks);

  test("displayName updates when count property changes", function (assert) {
    const extraNavItem = ExtraNavItem.create({
      name: "something",
    });

    assert.strictEqual(
      extraNavItem.displayName,
      "[en.filters.something.title count=0]"
    );

    extraNavItem.count = 2;

    assert.strictEqual(
      extraNavItem.displayName,
      "[en.filters.something.title_with_count count=2]"
    );
  });
});
