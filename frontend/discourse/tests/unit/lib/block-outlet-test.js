import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import BlockGroup from "discourse/blocks/builtin/block-group";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  hasBlock,
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";

module("Unit | Lib | block-outlet", function (hooks) {
  setupTest(hooks);

  module("isBlock (via getBlockMetadata)", function () {
    test("returns metadata for @block decorated components", function (assert) {
      @block("test-decorated")
      class DecoratedBlock extends Component {}

      assert.notStrictEqual(getBlockMetadata(DecoratedBlock), null);
    });

    test("returns null for plain Glimmer components", function (assert) {
      // eslint-disable-next-line ember/no-empty-glimmer-component-classes
      class PlainComponent extends Component {}

      assert.strictEqual(getBlockMetadata(PlainComponent), null);
    });

    test("returns null for non-component classes", function (assert) {
      class NotAComponent {}

      assert.strictEqual(getBlockMetadata(NotAComponent), null);
    });

    test("returns null/undefined for null/undefined", function (assert) {
      assert.strictEqual(getBlockMetadata(null), null);
      assert.strictEqual(getBlockMetadata(undefined), null);
    });
  });

  module("@block decorator", function () {
    test("sets blockName via getBlockMetadata", function (assert) {
      @block("my-block-name")
      class NamedBlock extends Component {}

      assert.strictEqual(
        getBlockMetadata(NamedBlock)?.blockName,
        "my-block-name"
      );
    });

    test("throws for non-Glimmer component targets", function (assert) {
      assert.throws(() => {
        @block("invalid-target")
        class NotAComponent {}

        return NotAComponent;
      }, /@block target must be a Glimmer component/);
    });

    test("marks component as block via getBlockMetadata check", function (assert) {
      @block("check-block")
      class CheckBlock extends Component {}

      assert.notStrictEqual(getBlockMetadata(CheckBlock), null);
    });

    test("sets blockMetadata with default values", function (assert) {
      @block("metadata-default")
      class MetadataDefaultBlock extends Component {}

      const meta = getBlockMetadata(MetadataDefaultBlock);
      assert.strictEqual(meta.blockName, "metadata-default");
      assert.strictEqual(meta.shortName, "metadata-default");
      assert.strictEqual(meta.namespace, null);
      assert.strictEqual(meta.namespaceType, "core");
      assert.false(meta.isContainer);
      assert.strictEqual(meta.description, "");
      assert.strictEqual(meta.decoratorClassNames, null);
      assert.strictEqual(meta.args, null);
      assert.strictEqual(meta.childArgs, null);
      assert.strictEqual(meta.constraints, null);
      assert.strictEqual(meta.validate, null);
      assert.strictEqual(meta.allowedOutlets, null);
      assert.strictEqual(meta.deniedOutlets, null);
    });

    test("sets blockMetadata with description", function (assert) {
      @block("metadata-description", {
        description: "A test block for metadata",
      })
      class MetadataDescriptionBlock extends Component {}

      assert.strictEqual(
        getBlockMetadata(MetadataDescriptionBlock).description,
        "A test block for metadata"
      );
    });

    test("sets blockMetadata with container flag", function (assert) {
      @block("metadata-container", { container: true })
      class MetadataContainerBlock extends Component {}

      assert.true(getBlockMetadata(MetadataContainerBlock).isContainer);
    });

    test("sets blockMetadata with args schema", function (assert) {
      @block("metadata-args", {
        args: {
          title: { type: "string", required: true },
          count: { type: "number", default: 5 },
        },
      })
      class MetadataArgsBlock extends Component {}

      assert.deepEqual(getBlockMetadata(MetadataArgsBlock).args, {
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

      assert.true(Object.isFrozen(getBlockMetadata(MetadataFrozenBlock)));
      assert.true(Object.isFrozen(getBlockMetadata(MetadataFrozenBlock).args));
    });

    test("sets blockMetadata with allowedOutlets", function (assert) {
      @block("metadata-allowed-outlets", {
        allowedOutlets: ["sidebar-*", "homepage-blocks"],
      })
      class AllowedOutletsBlock extends Component {}

      assert.deepEqual(getBlockMetadata(AllowedOutletsBlock).allowedOutlets, [
        "sidebar-*",
        "homepage-blocks",
      ]);
    });

    test("sets blockMetadata with deniedOutlets", function (assert) {
      @block("metadata-denied-outlets", {
        deniedOutlets: ["modal-*", "tooltip-*"],
      })
      class DeniedOutletsBlock extends Component {}

      assert.deepEqual(getBlockMetadata(DeniedOutletsBlock).deniedOutlets, [
        "modal-*",
        "tooltip-*",
      ]);
    });

    test("freezes allowedOutlets and deniedOutlets arrays", function (assert) {
      @block("metadata-frozen-outlets", {
        allowedOutlets: ["sidebar-*"],
        deniedOutlets: ["modal-*"],
      })
      class FrozenOutletsBlock extends Component {}

      assert.true(
        Object.isFrozen(getBlockMetadata(FrozenOutletsBlock).allowedOutlets)
      );
      assert.true(
        Object.isFrozen(getBlockMetadata(FrozenOutletsBlock).deniedOutlets)
      );
    });

    test("throws for conflicting outlet patterns", function (assert) {
      assert.throws(() => {
        @block("conflicting-outlets-block", {
          allowedOutlets: ["sidebar-*"],
          deniedOutlets: ["sidebar-blocks"],
        })
        class ConflictingOutletsBlock extends Component {}

        return ConflictingOutletsBlock;
      }, /matches both.*allowedOutlets.*deniedOutlets/);
    });

    test("throws for invalid allowedOutlets type", function (assert) {
      assert.throws(() => {
        @block("invalid-allowed-type-block", {
          allowedOutlets: "sidebar-*",
        })
        class InvalidAllowedTypeBlock extends Component {}

        return InvalidAllowedTypeBlock;
      }, /must be an array of strings/);
    });

    test("throws for invalid deniedOutlets type", function (assert) {
      assert.throws(() => {
        @block("invalid-denied-type-block", {
          deniedOutlets: { pattern: "sidebar-*" },
        })
        class InvalidDeniedTypeBlock extends Component {}

        return InvalidDeniedTypeBlock;
      }, /must be an array of strings/);
    });

    test("throws for invalid glob pattern syntax", function (assert) {
      assert.throws(() => {
        @block("invalid-glob-block", {
          allowedOutlets: ["[unclosed"],
        })
        class InvalidGlobBlock extends Component {}

        return InvalidGlobBlock;
      }, /not valid glob syntax/);
    });

    test("throws for unknown option key with suggestion", function (assert) {
      assert.throws(() => {
        @block("unknown-option-block", {
          containers: true,
        })
        class UnknownOptionBlock extends Component {}

        return UnknownOptionBlock;
      }, /unknown option.*"containers".*did you mean.*"container"/);
    });

    test("throws for multiple unknown option keys", function (assert) {
      assert.throws(() => {
        @block("multiple-unknown-block", {
          desc: "Test",
          containers: true,
        })
        class MultipleUnknownBlock extends Component {}

        return MultipleUnknownBlock;
      }, /unknown option.*"desc".*"containers".*Valid options are/);
    });

    test("throws for typo in deniedOutlets", function (assert) {
      assert.throws(() => {
        @block("typo-denied-block", {
          deniedOutlet: ["sidebar-*"],
        })
        class TypoDeniedBlock extends Component {}

        return TypoDeniedBlock;
      }, /unknown option.*"deniedOutlet".*did you mean.*"deniedOutlets"/);
    });

    test("accepts only valid option keys", function (assert) {
      @block("valid-options-block", {
        container: true,
        description: "Test block",
        args: { title: { type: "string" } },
        allowedOutlets: ["sidebar-*"],
        deniedOutlets: ["modal-*"],
      })
      class ValidOptionsBlock extends Component {}

      assert.true(getBlockMetadata(ValidOptionsBlock).isContainer);
      assert.strictEqual(
        getBlockMetadata(ValidOptionsBlock).description,
        "Test block"
      );
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

    test("throws for classNames with invalid type", function (assert) {
      assert.throws(() => {
        @block("block-invalid-classnames", {
          classNames: { foo: "bar" },
        })
        class BlockInvalidClassNames extends Component {}

        return BlockInvalidClassNames;
      }, /classNames.*must be a string, array, or function/);
    });

    test("accepts classNames as string", function (assert) {
      @block("block-string-classes", {
        classNames: "extra-class",
      })
      class BlockStringClasses extends Component {}

      assert.strictEqual(
        getBlockMetadata(BlockStringClasses).decoratorClassNames,
        "extra-class"
      );
    });

    test("accepts classNames as array", function (assert) {
      @block("block-array-classes", {
        classNames: ["class-a", "class-b"],
      })
      class BlockArrayClasses extends Component {}

      assert.deepEqual(
        getBlockMetadata(BlockArrayClasses).decoratorClassNames,
        ["class-a", "class-b"]
      );
    });

    test("accepts classNames as function", function (assert) {
      const classNamesFn = (args) => `dynamic-${args.name}`;

      @block("block-fn-classes", {
        classNames: classNamesFn,
      })
      class BlockFnClasses extends Component {}

      assert.strictEqual(
        getBlockMetadata(BlockFnClasses).decoratorClassNames,
        classNamesFn
      );
    });

    test("accepts classNames on non-container blocks", function (assert) {
      @block("non-container-with-classes", {
        classNames: "extra-class",
      })
      class NonContainerWithClasses extends Component {}

      assert.strictEqual(
        getBlockMetadata(NonContainerWithClasses).decoratorClassNames,
        "extra-class"
      );
      assert.false(getBlockMetadata(NonContainerWithClasses).isContainer);
    });
  });

  module("renderBlocks validation", function () {
    test("throws for unknown outlet names", function (assert) {
      @block("valid-block")
      class ValidBlock extends Component {}

      assert.throws(
        () =>
          withPluginApi((api) =>
            api.renderBlocks("unknown-outlet", [{ block: ValidBlock }])
          ),
        /Unknown block outlet/
      );
    });

    test("throws for missing block component", async function (assert) {
      await assert.rejects(
        _renderBlocks("hero-blocks", [{ args: { title: "test" } }]),
        /missing required "block" property/
      );
    });

    test("throws for non-@block decorated components", async function (assert) {
      // eslint-disable-next-line ember/no-empty-glimmer-component-classes
      class PlainComponent extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [{ block: PlainComponent }]),
        /not a valid @block-decorated component/
      );
    });

    test("throws for non-container block with children", async function (assert) {
      @block("leaf-block")
      class LeafBlock extends Component {}

      @block("child-block")
      class ChildBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: LeafBlock,
            children: [{ block: ChildBlock }],
          },
        ]),
        /cannot have children/
      );
    });

    test("throws for container block without children", async function (assert) {
      await assert.rejects(
        _renderBlocks("hero-blocks", [
          { block: BlockGroup, args: { name: "test" } },
        ]),
        /must have children/
      );
    });

    test("throws for reserved arg name: classNames", async function (assert) {
      @block("reserved-test")
      class ReservedTestBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: ReservedTestBlock,
            args: { classNames: "custom" },
          },
        ]),
        /Reserved arg names/i
      );
    });

    test("throws for reserved arg name: outletName", async function (assert) {
      @block("reserved-outlet")
      class ReservedOutletBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: ReservedOutletBlock,
            args: { outletName: "test" },
          },
        ]),
        /Reserved arg names/i
      );
    });

    test("throws for reserved arg name: children", async function (assert) {
      @block("reserved-children")
      class ReservedChildrenBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: ReservedChildrenBlock,
            args: { children: [] },
          },
        ]),
        /Reserved arg names/i
      );
    });

    test("throws for reserved arg name: conditions", async function (assert) {
      @block("reserved-conditions")
      class ReservedConditionsBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: ReservedConditionsBlock,
            args: { conditions: {} },
          },
        ]),
        /Reserved arg names/i
      );
    });

    test("throws for underscore-prefixed arg names", async function (assert) {
      @block("underscore-arg-reserved")
      class UnderscoreArgReservedBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: UnderscoreArgReservedBlock,
            args: { _privateArg: "value" },
          },
        ]),
        /Reserved arg names/i
      );
    });

    test("validates nested children recursively", async function (assert) {
      @block("nested-child")
      class NestedChildBlock extends Component {}

      // eslint-disable-next-line ember/no-empty-glimmer-component-classes
      class NotABlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: BlockGroup,
            args: { name: "test" },
            children: [{ block: NestedChildBlock }, { block: NotABlock }],
          },
        ]),
        /not a valid @block-decorated component/
      );
    });

    test("validates conditions via evaluator service", async function (assert) {
      @block("condition-validation")
      class ConditionValidationBlock extends Component {}

      const owner = getOwner(this);

      await assert.rejects(
        _renderBlocks(
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

    test("accepts valid layout entry", function (assert) {
      @block("valid-config", { args: { title: { type: "string" } } })
      class ValidConfigBlock extends Component {}

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [
          { block: ValidConfigBlock, args: { title: "Test" } },
        ])
      );

      assert.true(true, "no error thrown for valid configuration");
    });

    test("accepts container block with children", function (assert) {
      @block("container-child")
      class ContainerChildBlock extends Component {}

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockGroup,
            args: { name: "test" },
            children: [{ block: ContainerChildBlock }],
          },
        ])
      );

      assert.true(true, "no error thrown for container with children");
    });

    test("accepts block with valid conditions", function (assert) {
      @block("valid-conditions")
      class ValidConditionsBlock extends Component {}

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: ValidConditionsBlock,
            conditions: { type: "user", loggedIn: true },
          },
        ])
      );

      assert.true(true, "no error thrown for valid conditions");
    });

    test("throws for missing required arg", async function (assert) {
      @block("required-arg-block", {
        args: {
          title: { type: "string", required: true },
        },
      })
      class RequiredArgBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [{ block: RequiredArgBlock, args: {} }]),
        /missing required args\.title/
      );
    });

    test("throws for invalid arg type - string expected", async function (assert) {
      @block("string-arg-block", {
        args: {
          title: { type: "string" },
        },
      })
      class StringArgBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          { block: StringArgBlock, args: { title: 123 } },
        ]),
        /must be a string/
      );
    });

    test("throws for invalid arg type - number expected", async function (assert) {
      @block("number-arg-block", {
        args: {
          count: { type: "number" },
        },
      })
      class NumberArgBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          { block: NumberArgBlock, args: { count: "five" } },
        ]),
        /must be a number/
      );
    });

    test("throws for invalid arg type - boolean expected", async function (assert) {
      @block("boolean-arg-block", {
        args: {
          enabled: { type: "boolean" },
        },
      })
      class BooleanArgBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          { block: BooleanArgBlock, args: { enabled: "yes" } },
        ]),
        /must be a boolean/
      );
    });

    test("throws for invalid arg type - array expected", async function (assert) {
      @block("array-arg-block", {
        args: {
          tags: { type: "array" },
        },
      })
      class ArrayArgBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          { block: ArrayArgBlock, args: { tags: "tag1,tag2" } },
        ]),
        /must be an array/
      );
    });

    test("throws for invalid array item type", async function (assert) {
      @block("array-item-type-block", {
        args: {
          tags: { type: "array", itemType: "string" },
        },
      })
      class ArrayItemTypeBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
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

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: ValidSchemaArgsBlock,
            args: {
              title: "Hello",
              count: 5,
              enabled: true,
              tags: ["a", "b", "c"],
            },
          },
        ])
      );

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

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: OptionalArgsBlock,
            args: { title: "Required Only" },
          },
        ])
      );

      assert.true(true, "no error thrown when optional args missing");
    });

    test("throws when block is in denied outlet", async function (assert) {
      @block("denied-outlet-block", {
        deniedOutlets: ["hero-*"],
      })
      class DeniedOutletBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [{ block: DeniedOutletBlock }]),
        /cannot be rendered in outlet.*matches deniedOutlets pattern/
      );
    });

    test("throws when block is not in allowed outlet", async function (assert) {
      @block("not-allowed-outlet-block", {
        allowedOutlets: ["sidebar-*"],
      })
      class NotAllowedOutletBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [{ block: NotAllowedOutletBlock }]),
        /cannot be rendered in outlet.*does not match any allowedOutlets/
      );
    });

    test("permits block in allowed outlet", function (assert) {
      @block("allowed-outlet-block", {
        allowedOutlets: ["sidebar-*"],
      })
      class AllowedOutletBlock extends Component {}

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [{ block: AllowedOutletBlock }])
      );

      assert.true(true, "no error thrown for block in allowed outlet");
    });

    test("permits unrestricted block in any outlet", function (assert) {
      @block("unrestricted-outlet-block")
      class UnrestrictedOutletBlock extends Component {}

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: UnrestrictedOutletBlock }])
      );
      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [{ block: UnrestrictedOutletBlock }])
      );

      assert.true(true, "unrestricted block renders in any outlet");
    });
  });

  module("edge cases", function () {
    test("block names with invalid characters throw error", function (assert) {
      assert.throws(() => {
        @block("Invalid_Name")
        class InvalidNameBlock extends Component {}

        withTestBlockRegistration(() => registerBlock(InvalidNameBlock));
      }, /Block name .* is invalid/);
    });

    test("block names starting with number throw error", function (assert) {
      assert.throws(() => {
        @block("123-block")
        class NumericStartBlock extends Component {}

        withTestBlockRegistration(() => registerBlock(NumericStartBlock));
      }, /Block name .* is invalid/);
    });

    test("block names with uppercase throw error", function (assert) {
      assert.throws(() => {
        @block("MyBlock")
        class UppercaseBlock extends Component {}

        withTestBlockRegistration(() => registerBlock(UppercaseBlock));
      }, /Block name .* is invalid/);
    });

    test("valid block names with hyphens and numbers work", function (assert) {
      @block("my-block-1")
      class ValidBlock extends Component {}

      withTestBlockRegistration(() => registerBlock(ValidBlock));

      assert.true(hasBlock("my-block-1"));
    });

    test("unicode in block args works correctly", function (assert) {
      @block("unicode-args-block", {
        args: {
          title: { type: "string" },
        },
      })
      class UnicodeArgsBlock extends Component {}

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: UnicodeArgsBlock,
            args: { title: "日本語テスト 🎉 émoji" },
          },
        ])
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

      assert.deepEqual(getBlockMetadata(UnderscoreArgBlock).args, {
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
