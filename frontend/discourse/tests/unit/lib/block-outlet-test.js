import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  block,
  isBlock,
  renderBlocks,
} from "discourse/components/block-outlet";
import BlockGroup from "discourse/components/blocks/block-group";

module("Unit | Lib | block-outlet", function (hooks) {
  setupTest(hooks);

  module("isBlock", function () {
    test("returns true for @block decorated components", function (assert) {
      @block("test-decorated")
      class DecoratedBlock extends Component {}

      assert.true(isBlock(DecoratedBlock));
    });

    test("returns false for plain Glimmer components", function (assert) {
      // eslint-disable-next-line ember/no-empty-glimmer-component-classes
      class PlainComponent extends Component {}

      assert.false(isBlock(PlainComponent));
    });

    test("returns false for non-component classes", function (assert) {
      class NotAComponent {}

      assert.false(isBlock(NotAComponent));
    });

    test("returns false for null/undefined", function (assert) {
      assert.false(isBlock(null));
      assert.false(isBlock(undefined));
    });
  });

  module("@block decorator", function () {
    test("sets static blockName property", function (assert) {
      @block("my-block-name")
      class NamedBlock extends Component {}

      assert.strictEqual(NamedBlock.blockName, "my-block-name");
    });

    test("throws for non-Glimmer component targets", function (assert) {
      assert.throws(() => {
        @block("invalid-target")
        class NotAComponent {}

        return NotAComponent;
      }, /@block target must be a Glimmer component/);
    });

    test("marks component as block via isBlock check", function (assert) {
      @block("check-block")
      class CheckBlock extends Component {}

      assert.true(isBlock(CheckBlock));
    });
  });

  module("renderBlocks validation", function () {
    test("throws for unknown outlet names", function (assert) {
      @block("valid-block")
      class ValidBlock extends Component {}

      assert.throws(
        () => renderBlocks("unknown-outlet", [{ block: ValidBlock }]),
        /Unknown block outlet/
      );
    });

    test("throws for missing block component", function (assert) {
      assert.throws(
        () => renderBlocks("hero-blocks", [{ args: { title: "test" } }]),
        /missing a component/
      );
    });

    test("throws for non-@block decorated components", function (assert) {
      // eslint-disable-next-line ember/no-empty-glimmer-component-classes
      class PlainComponent extends Component {}

      assert.throws(
        () => renderBlocks("hero-blocks", [{ block: PlainComponent }]),
        /not a valid block/
      );
    });

    test("throws for non-container block with children", function (assert) {
      @block("leaf-block")
      class LeafBlock extends Component {}

      @block("child-block")
      class ChildBlock extends Component {}

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            {
              block: LeafBlock,
              children: [{ block: ChildBlock }],
            },
          ]),
        /cannot have children/
      );
    });

    test("throws for container block without children", function (assert) {
      assert.throws(
        () => renderBlocks("hero-blocks", [{ block: BlockGroup }]),
        /must have children/
      );
    });

    test("throws for reserved arg name: classNames", function (assert) {
      @block("reserved-test")
      class ReservedTestBlock extends Component {}

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            {
              block: ReservedTestBlock,
              args: { classNames: "custom" },
            },
          ]),
        /reserved arg names/
      );
    });

    test("throws for reserved arg name: outletName", function (assert) {
      @block("reserved-outlet")
      class ReservedOutletBlock extends Component {}

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            {
              block: ReservedOutletBlock,
              args: { outletName: "test" },
            },
          ]),
        /reserved arg names/
      );
    });

    test("throws for reserved arg name: children", function (assert) {
      @block("reserved-children")
      class ReservedChildrenBlock extends Component {}

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            {
              block: ReservedChildrenBlock,
              args: { children: [] },
            },
          ]),
        /reserved arg names/
      );
    });

    test("throws for reserved arg name: conditions", function (assert) {
      @block("reserved-conditions")
      class ReservedConditionsBlock extends Component {}

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            {
              block: ReservedConditionsBlock,
              args: { conditions: {} },
            },
          ]),
        /reserved arg names/
      );
    });

    test("throws for reserved arg name: $block$", function (assert) {
      @block("reserved-block-symbol")
      class ReservedBlockSymbolBlock extends Component {}

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            {
              block: ReservedBlockSymbolBlock,
              args: { $block$: "test" },
            },
          ]),
        /reserved arg names/
      );
    });

    test("throws for underscore-prefixed arg names", function (assert) {
      @block("underscore-arg")
      class UnderscoreArgBlock extends Component {}

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            {
              block: UnderscoreArgBlock,
              args: { _privateArg: "value" },
            },
          ]),
        /reserved arg names/
      );
    });

    test("validates nested children recursively", function (assert) {
      @block("nested-child")
      class NestedChildBlock extends Component {}

      // eslint-disable-next-line ember/no-empty-glimmer-component-classes
      class NotABlock extends Component {}

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            {
              block: BlockGroup,
              children: [{ block: NestedChildBlock }, { block: NotABlock }],
            },
          ]),
        /not a valid block/
      );
    });

    test("validates conditions via evaluator service", function (assert) {
      @block("condition-validation")
      class ConditionValidationBlock extends Component {}

      const owner = getOwner(this);

      assert.throws(
        () =>
          renderBlocks(
            "hero-blocks",
            [
              {
                block: ConditionValidationBlock,
                conditions: { type: "unknown-condition-type" },
              },
            ],
            owner
          ),
        /Unknown block condition type|Invalid conditions/
      );
    });

    test("accepts valid block configuration", function (assert) {
      @block("valid-config")
      class ValidConfigBlock extends Component {}

      renderBlocks("sidebar-blocks", [
        { block: ValidConfigBlock, args: { title: "Test" } },
      ]);

      assert.true(true, "no error thrown for valid configuration");
    });

    test("accepts container block with children", function (assert) {
      @block("container-child")
      class ContainerChildBlock extends Component {}

      renderBlocks("main-outlet-blocks", [
        {
          block: BlockGroup,
          children: [{ block: ContainerChildBlock }],
        },
      ]);

      assert.true(true, "no error thrown for container with children");
    });

    test("accepts block with valid conditions", function (assert) {
      @block("valid-conditions")
      class ValidConditionsBlock extends Component {}

      const owner = getOwner(this);

      renderBlocks(
        "header-blocks",
        [
          {
            block: ValidConditionsBlock,
            conditions: { type: "user", loggedIn: true },
          },
        ],
        owner
      );

      assert.true(true, "no error thrown for valid conditions");
    });
  });
});
