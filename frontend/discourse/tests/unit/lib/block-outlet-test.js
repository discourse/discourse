import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { block } from "discourse/blocks";
import {
  _clearLayoutLayer,
  _getOutletLayouts,
  _hasLayout,
  _renderBlocks,
  _resetOutletLayoutsForTesting,
  _setLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import BlockGroup from "discourse/blocks/builtin/block-group";
import HeadingThumbnail from "discourse/blocks/thumbnails/heading";
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
      assert.strictEqual(meta.displayName, null);
      assert.strictEqual(meta.icon, null);
      assert.strictEqual(meta.category, null);
      assert.strictEqual(meta.previewArgs, null);
      assert.strictEqual(meta.thumbnail, null);
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

    test("stores displayName, icon, category, previewArgs, thumbnail", function (assert) {
      @block("metadata-palette", {
        displayName: "Hero Banner",
        icon: "image",
        category: "Content",
        previewArgs: { title: "Sample title" },
        thumbnail: "/uploads/preview.png",
      })
      class MetadataPaletteBlock extends Component {}

      const meta = getBlockMetadata(MetadataPaletteBlock);
      assert.strictEqual(meta.displayName, "Hero Banner");
      assert.strictEqual(meta.icon, "image");
      assert.strictEqual(meta.category, "Content");
      assert.deepEqual(meta.previewArgs, { title: "Sample title" });
      assert.strictEqual(meta.thumbnail, "/uploads/preview.png");
    });

    test("freezes previewArgs object", function (assert) {
      @block("metadata-preview-frozen", {
        previewArgs: { title: "Sample" },
      })
      class MetadataPreviewFrozenBlock extends Component {}

      assert.true(
        Object.isFrozen(
          getBlockMetadata(MetadataPreviewFrozenBlock).previewArgs
        )
      );
    });

    test("throws for empty displayName", function (assert) {
      assert.throws(() => {
        @block("metadata-empty-display-name", { displayName: "  " })
        class EmptyDisplayNameBlock extends Component {}

        return EmptyDisplayNameBlock;
      }, /"displayName" must be a non-empty string/);
    });

    test("throws for non-string icon", function (assert) {
      assert.throws(() => {
        @block("metadata-bad-icon", { icon: 42 })
        class BadIconBlock extends Component {}

        return BadIconBlock;
      }, /"icon" must be a non-empty string/);
    });

    test("throws for non-object previewArgs", function (assert) {
      assert.throws(() => {
        @block("metadata-bad-preview", { previewArgs: "not-an-object" })
        class BadPreviewBlock extends Component {}

        return BadPreviewBlock;
      }, /"previewArgs" must be a plain object/);
    });

    test("throws for array previewArgs", function (assert) {
      assert.throws(() => {
        @block("metadata-array-preview", { previewArgs: [1, 2, 3] })
        class ArrayPreviewBlock extends Component {}

        return ArrayPreviewBlock;
      }, /"previewArgs" must be a plain object/);
    });

    test("throws for a thumbnail that is neither a URL string nor a component", function (assert) {
      assert.throws(() => {
        @block("metadata-bad-thumbnail", { thumbnail: 123 })
        class BadThumbnailBlock extends Component {}

        return BadThumbnailBlock;
      }, /"thumbnail" must be a non-empty URL string/);
    });

    test("accepts a component thumbnail", function (assert) {
      @block("metadata-component-thumbnail", { thumbnail: HeadingThumbnail })
      class ComponentThumbnailBlock extends Component {}

      assert.strictEqual(
        getBlockMetadata(ComponentThumbnailBlock).thumbnail,
        HeadingThumbnail
      );
    });

    test("accepts a { light, dark } thumbnail pair", function (assert) {
      const pair = { light: "/uploads/light.png", dark: "/uploads/dark.png" };

      @block("metadata-lightdark-thumbnail", { thumbnail: pair })
      class LightDarkThumbnailBlock extends Component {}

      assert.strictEqual(
        getBlockMetadata(LightDarkThumbnailBlock).thumbnail,
        pair
      );
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
      const stub = sinon.stub(console, "warn");

      @block("metadata-denied-outlets", {
        deniedOutlets: ["modal-*", "tooltip-*"],
      })
      class DeniedOutletsBlock extends Component {}

      assert.deepEqual(getBlockMetadata(DeniedOutletsBlock).deniedOutlets, [
        "modal-*",
        "tooltip-*",
      ]);
      assert.true(
        stub.calledWithMatch(
          '[Blocks] Block "metadata-denied-outlets": deniedOutlets pattern "modal-*" does not match any registered outlet.'
        )
      );
      assert.true(
        stub.calledWithMatch(
          '[Blocks] Block "metadata-denied-outlets": deniedOutlets pattern "tooltip-*" does not match any registered outlet.'
        )
      );

      stub.restore();
    });

    test("freezes allowedOutlets and deniedOutlets arrays", function (assert) {
      const stub = sinon.stub(console, "warn");

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
      assert.true(
        stub.calledWithMatch(
          '[Blocks] Block "metadata-frozen-outlets": deniedOutlets pattern "modal-*" does not match any registered outlet.'
        )
      );

      stub.restore();
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
      const stub = sinon.stub(console, "warn");

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
      assert.true(
        stub.calledWithMatch(
          '[Blocks] Block "valid-options-block": deniedOutlets pattern "modal-*" does not match any registered outlet.'
        )
      );

      stub.restore();
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
        _renderBlocks("hero-blocks", [{ block: BlockGroup }]),
        /must have children/
      );
    });

    test("throws for undeclared arg: classNames", async function (assert) {
      @block("reserved-test")
      class ReservedTestBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: ReservedTestBlock,
            args: { classNames: "custom" },
          },
        ]),
        /does not declare an args schema/i
      );
    });

    test("throws for undeclared arg: outletName", async function (assert) {
      @block("reserved-outlet")
      class ReservedOutletBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: ReservedOutletBlock,
            args: { outletName: "test" },
          },
        ]),
        /does not declare an args schema/i
      );
    });

    test("throws for undeclared arg: children", async function (assert) {
      @block("reserved-children")
      class ReservedChildrenBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: ReservedChildrenBlock,
            args: { children: [] },
          },
        ]),
        /does not declare an args schema/i
      );
    });

    test("throws for undeclared arg: conditions", async function (assert) {
      @block("reserved-conditions")
      class ReservedConditionsBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: ReservedConditionsBlock,
            args: { conditions: {} },
          },
        ]),
        /does not declare an args schema/i
      );
    });

    test("throws for undeclared underscore-prefixed arg", async function (assert) {
      @block("underscore-arg-reserved")
      class UnderscoreArgReservedBlock extends Component {}

      await assert.rejects(
        _renderBlocks("hero-blocks", [
          {
            block: UnderscoreArgReservedBlock,
            args: { _privateArg: "value" },
          },
        ]),
        /does not declare an args schema/i
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
            id: "test",
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
            id: "test",
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

  module("layout resolution chain", function (innerHooks) {
    @block("resolution-chain-block", { args: { label: { type: "string" } } })
    class ResolutionChainBlock extends Component {}

    innerHooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
    });

    test("setLayoutLayer registers a code-default layout", async function (assert) {
      const owner = getOwner(this);
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.CODE_DEFAULT,
        [{ block: ResolutionChainBlock, args: { label: "code" } }],
        owner
      );

      assert.true(_hasLayout("homepage-blocks"));
      const resolved = _getOutletLayouts().get("homepage-blocks");
      const layout = await resolved.validatedLayout;
      assert.strictEqual(layout[0].args.label, "code");
    });

    test("theme layer overrides code-default", async function (assert) {
      const owner = getOwner(this);
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.CODE_DEFAULT,
        [{ block: ResolutionChainBlock, args: { label: "code" } }],
        owner
      );
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "theme" } }],
        owner,
        { themeId: 5 }
      );

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "theme");
    });

    test("session-draft layer overrides theme", async function (assert) {
      const owner = getOwner(this);
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "theme" } }],
        owner,
        { themeId: 5 }
      );
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [{ block: ResolutionChainBlock, args: { label: "draft" } }],
        owner
      );

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "draft");
    });

    test("multiple themes — owner is the maximum stack rank", async function (assert) {
      const owner = getOwner(this);
      // themeId 3 is the parent (stack index 0); themeId 7 is a component
      // further down the stack (index 1). The most-derived theme (the
      // component) overrides the parent and owns the outlet.
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "first" } }],
        owner,
        { themeId: 3, themeStackIndex: 0 }
      );
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "second" } }],
        owner,
        { themeId: 7, themeStackIndex: 1 }
      );

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "second");
    });

    test("owner resolution is independent of registration order", async function (assert) {
      const owner = getOwner(this);
      // Register the higher-ranked component FIRST, then the parent. The
      // component (maximum stack index) still owns the outlet — order doesn't
      // matter, only the stack rank.
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "second" } }],
        owner,
        { themeId: 7, themeStackIndex: 1 }
      );
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "first" } }],
        owner,
        { themeId: 3, themeStackIndex: 0 }
      );

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "second");
    });

    test("re-registering a theme with the same themeId keeps its stack rank", async function (assert) {
      const owner = getOwner(this);
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "a" } }],
        owner,
        { themeId: 3, themeStackIndex: 0 }
      );
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "b" } }],
        owner,
        { themeId: 7, themeStackIndex: 1 }
      );

      // The component (theme 7, rank 1) owns. Re-register it with new content
      // and WITHOUT a stack index. The originally-stamped rank (1) is preserved,
      // so theme 7 stays the owner — a MessageBus update can't silently change
      // ownership.
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "b-updated" } }],
        owner,
        { themeId: 7 }
      );

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "b-updated");
    });

    test("clearing session-draft falls back to theme", async function (assert) {
      const owner = getOwner(this);
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "theme" } }],
        owner,
        { themeId: 5 }
      );
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [{ block: ResolutionChainBlock, args: { label: "draft" } }],
        owner
      );

      _clearLayoutLayer("homepage-blocks", LAYOUT_LAYERS.SESSION_DRAFT);

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "theme");
    });

    test("clearing theme by themeId leaves other themes in place", async function (assert) {
      const owner = getOwner(this);
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "first" } }],
        owner,
        { themeId: 3 }
      );
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "second" } }],
        owner,
        { themeId: 7 }
      );

      _clearLayoutLayer("homepage-blocks", LAYOUT_LAYERS.THEME, {
        themeId: 7,
      });

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "first");
    });

    test("clearing all layers removes the outlet entirely", async function (assert) {
      const owner = getOwner(this);
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.CODE_DEFAULT,
        [{ block: ResolutionChainBlock, args: { label: "code" } }],
        owner
      );
      assert.true(_hasLayout("homepage-blocks"));

      _clearLayoutLayer("homepage-blocks", LAYOUT_LAYERS.CODE_DEFAULT);
      assert.false(_hasLayout("homepage-blocks"));
    });

    test("setLayoutLayer rejects unknown layer names", function (assert) {
      assert.throws(
        () =>
          _setLayoutLayer("homepage-blocks", "bogus-layer", [], getOwner(this)),
        /Unknown layout layer/
      );
    });

    test("setLayoutLayer requires themeId for the theme layer", function (assert) {
      assert.throws(
        () =>
          _setLayoutLayer(
            "homepage-blocks",
            LAYOUT_LAYERS.THEME,
            [],
            getOwner(this)
          ),
        /requires options\.themeId/
      );
    });

    test("renderBlocks does not throw when a theme layer is already set", async function (assert) {
      const owner = getOwner(this);
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "theme" } }],
        owner,
        { themeId: 5 }
      );

      // Calling _renderBlocks (the code-default registration path) on an
      // outlet that already has a theme layer should succeed — the duplicate
      // guard is scoped to the code-default layer only.
      await _renderBlocks(
        "homepage-blocks",
        [{ block: ResolutionChainBlock, args: { label: "code" } }],
        owner
      );

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "theme");
    });

    test("renderBlocks throws on a duplicate overridable (seed) registration", async function (assert) {
      const owner = getOwner(this);
      await _renderBlocks(
        "homepage-blocks",
        [{ block: ResolutionChainBlock, args: { label: "first" } }],
        owner,
        { sourceId: "plugin-a" }
      );

      assert.throws(
        () =>
          _renderBlocks(
            "homepage-blocks",
            [{ block: ResolutionChainBlock, args: { label: "second" } }],
            owner,
            { sourceId: "plugin-b" }
          ),
        /already has an overridable layout registered.*plugin-a.*plugin-b/
      );
    });

    test("a locked code layout outranks theme and session-draft", async function (assert) {
      const owner = getOwner(this);
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "theme" } }],
        owner,
        { themeId: 5, themeStackIndex: 0 }
      );
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [{ block: ResolutionChainBlock, args: { label: "draft" } }],
        owner
      );
      await _renderBlocks(
        "homepage-blocks",
        [{ block: ResolutionChainBlock, args: { label: "locked" } }],
        owner,
        { overridable: false }
      );

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "locked");
    });

    test("an overridable seed is the fallback below theme", async function (assert) {
      const owner = getOwner(this);
      await _renderBlocks(
        "homepage-blocks",
        [{ block: ResolutionChainBlock, args: { label: "seed" } }],
        owner
      );
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "theme" } }],
        owner,
        { themeId: 5, themeStackIndex: 0 }
      );

      // The owner theme wins while present.
      let resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "theme");

      // Clear the theme and the seed resolves.
      _clearLayoutLayer("homepage-blocks", LAYOUT_LAYERS.THEME);
      resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "seed");
    });

    test("a locked layout and an overridable seed coexist (either arrival order)", async function (assert) {
      const owner = getOwner(this);
      // Seed first, then the lock arrives — no throw.
      await _renderBlocks(
        "homepage-blocks",
        [{ block: ResolutionChainBlock, args: { label: "seed" } }],
        owner
      );
      await _renderBlocks(
        "homepage-blocks",
        [{ block: ResolutionChainBlock, args: { label: "locked" } }],
        owner,
        { overridable: false }
      );

      // The lock wins while both are present.
      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "locked");

      // Clearing the public code layer removes BOTH slots — the seed does not
      // survive a lock clear.
      _clearLayoutLayer("homepage-blocks", LAYOUT_LAYERS.CODE_DEFAULT);
      assert.false(_hasLayout("homepage-blocks"));
    });

    test("locked + locked is a conflict and throws", async function (assert) {
      const owner = getOwner(this);
      await _renderBlocks(
        "homepage-blocks",
        [{ block: ResolutionChainBlock, args: { label: "first" } }],
        owner,
        { overridable: false, sourceId: "plugin-a" }
      );

      assert.throws(
        () =>
          _renderBlocks(
            "homepage-blocks",
            [{ block: ResolutionChainBlock, args: { label: "second" } }],
            owner,
            { overridable: false, sourceId: "plugin-b" }
          ),
        /already has a locked layout registered.*plugin-a.*plugin-b/
      );
    });

    test("stamps provenance on each resolved entry and keeps themeId", async function (assert) {
      const owner = getOwner(this);
      await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "theme" } }],
        owner,
        { themeId: 5, themeStackIndex: 2 }
      );

      const entry = _getOutletLayouts().get("homepage-blocks");
      assert.strictEqual(entry.source, "theme", "stamps the source");
      assert.strictEqual(entry.sourceId, 5, "stamps the source id (themeId)");
      assert.strictEqual(entry.themeStackIndex, 2, "stamps the stack rank");
      assert.strictEqual(
        entry.themeId,
        5,
        "keeps themeId stamped (the i18n seam)"
      );
    });

    test("lazy mode: setLayoutLayer returns undefined and defers validation", async function (assert) {
      const result = _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "lazy" } }],
        getOwner(this),
        { themeId: 5, lazy: true }
      );

      assert.strictEqual(
        result,
        undefined,
        "lazy mode returns nothing — caller doesn't trigger validation"
      );

      // The layer is published immediately, but validation only fires on
      // the first read of `validatedLayout`. Reading it now returns the
      // (now-memoized) Promise.
      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "lazy");
    });

    test("lazy mode: validation Promise is memoized across reads", async function (assert) {
      _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: ResolutionChainBlock, args: { label: "memoised" } }],
        getOwner(this),
        { themeId: 5, lazy: true }
      );

      const record = _getOutletLayouts().get("homepage-blocks");
      const firstRead = record.validatedLayout;
      const secondRead = record.validatedLayout;

      assert.strictEqual(
        firstRead,
        secondRead,
        "subsequent reads return the same Promise reference"
      );
      await firstRead;
    });

    test("permissive mode: empty container resolves with warnings instead of rejecting", async function (assert) {
      // Strict mode (no `permissive` flag) rejects with the existing
      // BlockError — kept here as a regression check before switching modes.
      await assert.rejects(
        _setLayoutLayer(
          "homepage-blocks",
          LAYOUT_LAYERS.SESSION_DRAFT,
          [{ block: BlockGroup }],
          getOwner(this)
        ),
        /must have children/,
        "strict mode still rejects"
      );

      _resetOutletLayoutsForTesting();

      // Permissive mode: same invalid layout, but the layer accepts it,
      // captures the validation message on `validationWarnings`, and
      // resolves with the layout for the renderer.
      const result = _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [{ block: BlockGroup }],
        getOwner(this),
        { permissive: true }
      );

      const resolved = await result;
      assert.deepEqual(
        resolved.map((e) => e.block),
        [BlockGroup],
        "permissive mode resolves with the layout"
      );

      const record = _getOutletLayouts().get("homepage-blocks");
      assert.strictEqual(
        record.validationWarnings.length,
        1,
        "warning captured on the layer entry"
      );
      assert.true(
        /must have children/.test(record.validationWarnings[0].message),
        "warning message describes the validation failure"
      );
    });

    test("permissive mode: valid layout still resolves cleanly with no warnings", async function (assert) {
      const resolved = await _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [{ block: ResolutionChainBlock, args: { label: "ok" } }],
        getOwner(this),
        { permissive: true }
      );
      assert.strictEqual(resolved[0].args.label, "ok");

      const record = _getOutletLayouts().get("homepage-blocks");
      assert.strictEqual(record.validationWarnings.length, 0);
    });
  });
});
