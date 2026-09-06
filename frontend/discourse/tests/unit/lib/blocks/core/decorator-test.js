import Component from "@glimmer/component";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

module("Unit | Lib | blocks/core/decorator", function (hooks) {
  setupTest(hooks);

  test("functional invocation returns the decorated class", function (assert) {
    // eslint-disable-next-line ember/no-empty-glimmer-component-classes
    class TestBlock extends Component {}

    const Decorated = block("functional-return-block")(TestBlock);

    assert.strictEqual(
      Decorated,
      TestBlock,
      "the decorator returns the class it decorated"
    );
    assert.strictEqual(
      getBlockMetadata(Decorated).blockName,
      "functional-return-block",
      "the returned class carries the block metadata"
    );
  });
});
