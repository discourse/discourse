import Component from "@glimmer/component";
import { expectTypeOf } from "expect-type";
import {
  type ArgSchema,
  type ArgType,
  block,
  type BlockClassNames,
  BlockCondition,
  type BlockConstraints,
  type BlockMetadata,
  type BlockNamespaceType,
  type BlockOptions,
  type BlockPaletteVariant,
  type BlockPaletteVariantDefinition,
  type BlockValidateFn,
  type ChildArgSchema,
  type LayoutEntry,
} from "discourse/blocks";
import { blockCondition } from "discourse/blocks/conditions";

// The author-facing types must be importable from the documented public entry
// point (`discourse/blocks`), not just from the internal types module.
expectTypeOf<ArgSchema>().not.toBeAny();
expectTypeOf<ArgType>().not.toBeAny();
expectTypeOf<BlockClassNames>().not.toBeAny();
expectTypeOf<BlockConstraints>().not.toBeAny();
expectTypeOf<BlockMetadata>().not.toBeAny();
expectTypeOf<BlockNamespaceType>().not.toBeAny();
expectTypeOf<BlockOptions>().not.toBeAny();
expectTypeOf<BlockPaletteVariant>().not.toBeAny();
expectTypeOf<BlockPaletteVariantDefinition>().not.toBeAny();
expectTypeOf<BlockValidateFn>().not.toBeAny();
expectTypeOf<ChildArgSchema>().not.toBeAny();
expectTypeOf<LayoutEntry>().not.toBeAny();

// Spot-check the shapes typed plugins depend on.
expectTypeOf<LayoutEntry["block"]>().not.toBeAny();
expectTypeOf<BlockOptions["container"]>().toEqualTypeOf<boolean | undefined>();
expectTypeOf<"string">().toExtend<ArgType>();

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
class ExampleBlock extends Component {}

// Both decorators return the class they decorate, so functional (non-`@`)
// invocation keeps the class identity for plain-JS and typed callers alike.
expectTypeOf(block("example")(ExampleBlock)).toEqualTypeOf<
  typeof ExampleBlock
>();

class ExampleCondition extends BlockCondition {
  evaluate(): boolean {
    return true;
  }
}

expectTypeOf(
  blockCondition({ type: "example" })(ExampleCondition)
).toEqualTypeOf<typeof ExampleCondition>();
