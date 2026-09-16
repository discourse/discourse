import Component from "@glimmer/component";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
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

  module("category", function () {
    test("accepts a known category silently", function (assert) {
      const warn = sinon.stub(console, "warn");
      try {
        @block("category-known", { category: "media" })
        class KnownCategoryBlock extends Component {}

        assert.strictEqual(
          getBlockMetadata(KnownCategoryBlock).category,
          "media"
        );
        assert.true(warn.notCalled);
      } finally {
        warn.restore();
      }
    });

    test("warns about a category outside the known set but keeps the block", function (assert) {
      const warn = sinon.stub(console, "warn");
      try {
        @block("category-unknown", { category: "Widgets" })
        class UnknownCategoryBlock extends Component {}

        assert.notStrictEqual(
          getBlockMetadata(UnknownCategoryBlock),
          null,
          "still registered"
        );
        assert.true(
          warn.calledWithMatch(
            /category-unknown.*"Widgets".*layout, text, media, actions, community/
          ),
          "names the block, the value, and the accepted set"
        );
      } finally {
        warn.restore();
      }
    });
  });
});
