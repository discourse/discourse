import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { defineBlockDataSource } from "discourse/blocks";
import { isBlockDataSource } from "discourse/lib/blocks/-internals/data-source";

module("Unit | Blocks | data-source supplemental", function (hooks) {
  setupTest(hooks);

  test("the brand must belong to the value itself", function (assert) {
    const source = defineBlockDataSource({ resolve: () => null });

    assert.false(
      isBlockDataSource(Object.create(source)),
      "an object inheriting the brand is not a data source"
    );
  });
});
