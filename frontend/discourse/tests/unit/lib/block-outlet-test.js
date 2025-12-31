import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import BlockGroup from "discourse/blocks/block-group";
import {
  block,
  isBlock,
  renderBlocks,
} from "discourse/components/block-outlet";
import {
  _registerBlock,
  blockRegistry,
  withTestBlockRegistration,
} from "discourse/lib/blocks/registration";

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

    test("sets blockMetadata with default values", function (assert) {
      @block("metadata-default")
      class MetadataDefaultBlock extends Component {}

      assert.deepEqual(MetadataDefaultBlock.blockMetadata, {
        description: "",
        container: false,
        args: null,
      });
    });

    test("sets blockMetadata with description", function (assert) {
      @block("metadata-description", {
        description: "A test block for metadata",
      })
      class MetadataDescriptionBlock extends Component {}

      assert.strictEqual(
        MetadataDescriptionBlock.blockMetadata.description,
        "A test block for metadata"
      );
    });

    test("sets blockMetadata with container flag", function (assert) {
      @block("metadata-container", { container: true })
      class MetadataContainerBlock extends Component {}

      assert.true(MetadataContainerBlock.blockMetadata.container);
    });

    test("sets blockMetadata with args schema", function (assert) {
      @block("metadata-args", {
        args: {
          title: { type: "string", required: true },
          count: { type: "number", default: 5 },
        },
      })
      class MetadataArgsBlock extends Component {}

      assert.deepEqual(MetadataArgsBlock.blockMetadata.args, {
        title: { type: "string", required: true },
        count: { type: "number", default: 5 },
      });
    });

    test("freezes blockMetadata object", function (assert) {
      @block("metadata-frozen", {
        description: "Frozen block",
        args: { title: { type: "string" } },
      })
      class MetadataFrozenBlock extends Component {}

      assert.true(Object.isFrozen(MetadataFrozenBlock.blockMetadata));
      assert.true(Object.isFrozen(MetadataFrozenBlock.blockMetadata.args));
    });

    test("throws for invalid arg schema - missing type", function (assert) {
      assert.throws(() => {
        @block("invalid-schema-no-type", {
          args: { title: { required: true } },
        })
        class InvalidSchemaBlock extends Component {}

        return InvalidSchemaBlock;
      }, /missing required "type" property/);
    });

    test("throws for invalid arg schema - invalid type", function (assert) {
      assert.throws(() => {
        @block("invalid-schema-bad-type", {
          args: { title: { type: "invalid" } },
        })
        class InvalidTypeBlock extends Component {}

        return InvalidTypeBlock;
      }, /invalid type "invalid"/);
    });

    test("throws for invalid arg schema - unknown properties", function (assert) {
      assert.throws(() => {
        @block("invalid-schema-unknown-prop", {
          args: { title: { type: "string", unknownProp: true } },
        })
        class UnknownPropBlock extends Component {}

        return UnknownPropBlock;
      }, /unknown properties/);
    });
  });

  module("renderBlocks validation", function () {
    test("throws for unknown outlet names", function (assert) {
      @block("valid-block")
      class ValidBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(ValidBlock));

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

      withTestBlockRegistration(() => {
        _registerBlock(LeafBlock);
        _registerBlock(ChildBlock);
      });

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

      withTestBlockRegistration(() => _registerBlock(ReservedTestBlock));

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

      withTestBlockRegistration(() => _registerBlock(ReservedOutletBlock));

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

      withTestBlockRegistration(() => _registerBlock(ReservedChildrenBlock));

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

      withTestBlockRegistration(() => _registerBlock(ReservedConditionsBlock));

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

      withTestBlockRegistration(() => _registerBlock(ReservedBlockSymbolBlock));

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
      @block("underscore-arg-reserved")
      class UnderscoreArgReservedBlock extends Component {}

      withTestBlockRegistration(() =>
        _registerBlock(UnderscoreArgReservedBlock)
      );

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            {
              block: UnderscoreArgReservedBlock,
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

      withTestBlockRegistration(() => _registerBlock(NestedChildBlock));

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

      withTestBlockRegistration(() => _registerBlock(ConditionValidationBlock));

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

      withTestBlockRegistration(() => _registerBlock(ValidConfigBlock));

      renderBlocks("sidebar-blocks", [
        { block: ValidConfigBlock, args: { title: "Test" } },
      ]);

      assert.true(true, "no error thrown for valid configuration");
    });

    test("accepts container block with children", function (assert) {
      @block("container-child")
      class ContainerChildBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(ContainerChildBlock));

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

      withTestBlockRegistration(() => _registerBlock(ValidConditionsBlock));

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

    test("throws for missing required arg", function (assert) {
      @block("required-arg-block", {
        args: {
          title: { type: "string", required: true },
        },
      })
      class RequiredArgBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(RequiredArgBlock));

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [{ block: RequiredArgBlock, args: {} }]),
        /missing required arg "title"/
      );
    });

    test("throws for invalid arg type - string expected", function (assert) {
      @block("string-arg-block", {
        args: {
          title: { type: "string" },
        },
      })
      class StringArgBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(StringArgBlock));

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            { block: StringArgBlock, args: { title: 123 } },
          ]),
        /must be a string/
      );
    });

    test("throws for invalid arg type - number expected", function (assert) {
      @block("number-arg-block", {
        args: {
          count: { type: "number" },
        },
      })
      class NumberArgBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(NumberArgBlock));

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            { block: NumberArgBlock, args: { count: "five" } },
          ]),
        /must be a number/
      );
    });

    test("throws for invalid arg type - boolean expected", function (assert) {
      @block("boolean-arg-block", {
        args: {
          enabled: { type: "boolean" },
        },
      })
      class BooleanArgBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(BooleanArgBlock));

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            { block: BooleanArgBlock, args: { enabled: "yes" } },
          ]),
        /must be a boolean/
      );
    });

    test("throws for invalid arg type - array expected", function (assert) {
      @block("array-arg-block", {
        args: {
          tags: { type: "array" },
        },
      })
      class ArrayArgBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(ArrayArgBlock));

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            { block: ArrayArgBlock, args: { tags: "tag1,tag2" } },
          ]),
        /must be an array/
      );
    });

    test("throws for invalid array item type", function (assert) {
      @block("array-item-type-block", {
        args: {
          tags: { type: "array", itemType: "string" },
        },
      })
      class ArrayItemTypeBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(ArrayItemTypeBlock));

      assert.throws(
        () =>
          renderBlocks("hero-blocks", [
            {
              block: ArrayItemTypeBlock,
              args: { tags: ["valid", 123, "also-valid"] },
            },
          ]),
        /must be a string/
      );
    });

    test("accepts valid args matching schema", function (assert) {
      @block("valid-schema-args", {
        args: {
          title: { type: "string", required: true },
          count: { type: "number" },
          enabled: { type: "boolean" },
          tags: { type: "array", itemType: "string" },
        },
      })
      class ValidSchemaArgsBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(ValidSchemaArgsBlock));

      renderBlocks("hero-blocks", [
        {
          block: ValidSchemaArgsBlock,
          args: {
            title: "Hello",
            count: 5,
            enabled: true,
            tags: ["a", "b", "c"],
          },
        },
      ]);

      assert.true(true, "no error thrown for valid args");
    });

    test("accepts optional args as undefined", function (assert) {
      @block("optional-args-block", {
        args: {
          title: { type: "string", required: true },
          subtitle: { type: "string" },
        },
      })
      class OptionalArgsBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(OptionalArgsBlock));

      renderBlocks("hero-blocks", [
        {
          block: OptionalArgsBlock,
          args: { title: "Required Only" },
        },
      ]);

      assert.true(true, "no error thrown when optional args missing");
    });
  });

  module("edge cases", function () {
    test("block names with invalid characters throw error", function (assert) {
      assert.throws(() => {
        @block("Invalid_Name")
        class InvalidNameBlock extends Component {}

        withTestBlockRegistration(() => _registerBlock(InvalidNameBlock));
      }, /Block name .* is invalid/);
    });

    test("block names starting with number throw error", function (assert) {
      assert.throws(() => {
        @block("123-block")
        class NumericStartBlock extends Component {}

        withTestBlockRegistration(() => _registerBlock(NumericStartBlock));
      }, /Block name .* is invalid/);
    });

    test("block names with uppercase throw error", function (assert) {
      assert.throws(() => {
        @block("MyBlock")
        class UppercaseBlock extends Component {}

        withTestBlockRegistration(() => _registerBlock(UppercaseBlock));
      }, /Block name .* is invalid/);
    });

    test("valid block names with hyphens and numbers work", function (assert) {
      @block("my-block-1")
      class ValidBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(ValidBlock));

      assert.true(blockRegistry.has("my-block-1"));
    });

    test("unicode in block args works correctly", function (assert) {
      @block("unicode-args-block", {
        args: {
          title: { type: "string" },
        },
      })
      class UnicodeArgsBlock extends Component {}

      withTestBlockRegistration(() => _registerBlock(UnicodeArgsBlock));

      renderBlocks(
        "hero-blocks",
        [
          {
            block: UnicodeArgsBlock,
            args: { title: "日本語テスト 🎉 émoji" },
          },
        ],
        getOwner(this)
      );

      assert.true(true, "unicode args accepted without error");
    });

    test("arg names with special characters in schema throw error", function (assert) {
      assert.throws(() => {
        @block("special-arg-names-block", {
          args: {
            "my@arg": { type: "string" },
          },
        })
        class SpecialArgNamesBlock extends Component {}

        return SpecialArgNamesBlock;
      }, /arg name .* is invalid/);
    });

    test("arg names starting with number in schema throw error", function (assert) {
      assert.throws(() => {
        @block("numeric-arg-names-block", {
          args: {
            "123title": { type: "string" },
          },
        })
        class NumericArgNamesBlock extends Component {}

        return NumericArgNamesBlock;
      }, /arg name .* is invalid/);
    });

    test("valid arg names with underscores work", function (assert) {
      @block("underscore-arg-block", {
        args: {
          my_arg_name: { type: "string" },
        },
      })
      class UnderscoreArgBlock extends Component {}

      assert.deepEqual(UnderscoreArgBlock.blockMetadata.args, {
        my_arg_name: { type: "string" },
      });
    });
  });

  module("condition edge cases", function () {
    test("empty conditions array renders block (vacuous truth)", function (assert) {
      const blocksService = this.owner.lookup("service:blocks");

      const result = blocksService.evaluate([]);

      assert.true(result, "empty AND array returns true");
    });

    test("empty any array does not render block", function (assert) {
      const blocksService = this.owner.lookup("service:blocks");

      const result = blocksService.evaluate({ any: [] });

      assert.false(result, "empty OR array returns false");
    });
  });
});
