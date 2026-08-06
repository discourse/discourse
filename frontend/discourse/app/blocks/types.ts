import type Component from "@glimmer/component";

/**
 * Public data shapes for the blocks API, shared by the `@block` decorator, the
 * registry, and the render pipeline. Author-facing types live here (rather than
 * under `-internals/`) so consumers can import them from `discourse/blocks`
 * without reaching across the internal boundary.
 */

/** The namespace category a block name resolves to. */
export type BlockNamespaceType = "core" | "plugin" | "theme";

/** The value type of a block argument. */
export type ArgType =
  | "string"
  | "number"
  | "boolean"
  | "array"
  | "object"
  | "any";

/**
 * Additional CSS classes for a block, as a string, an array of strings, or a
 * function computing them from the block's args.
 */
export type BlockClassNames =
  | string
  | string[]
  | ((args: Record<string, unknown>) => string);

/** Custom cross-arg validation invoked with the block's resolved args. */
export type BlockValidateFn = (args: Record<string, unknown>) => unknown;

/**
 * Cross-arg validation constraints. The precise shape is defined and enforced by
 * the constraints validator; treated opaquely at the type level here.
 */
export type BlockConstraints = Record<string, unknown>;

/** Schema describing and validating a single block argument. */
export interface ArgSchema {
  /** The argument's value type. */
  type: ArgType;

  /** Whether the argument must be provided. Defaults to `false`. */
  required?: boolean;

  /** Default value applied when the argument is omitted. */
  default?: unknown;

  /** Element type for `array` arguments. */
  itemType?: "string" | "number" | "boolean";

  /** Regular expression a `string` value must match. */
  pattern?: RegExp;

  /** Minimum length for a `string` or `array` value. */
  minLength?: number;

  /** Maximum length for a `string` or `array` value. */
  maxLength?: number;

  /** Minimum value for a `number`. */
  min?: number;

  /** Maximum value for a `number`. */
  max?: number;

  /** Whether a `number` must be an integer. */
  integer?: boolean;

  /** Allowed values for the argument. */
  enum?: unknown[];

  /** Allowed values for individual items of an `array` argument. */
  itemEnum?: unknown[];

  /** Nested schema for an `object` argument's properties, validated recursively. */
  properties?: Record<string, ArgSchema>;

  /**
   * Required class (or a `"model:*"` string, resolved via the registry) for an
   * `object` argument's value. Mutually exclusive with `properties`.
   */
  instanceOf?: (abstract new (...args: unknown[]) => object) | string;

  /**
   * Human-readable class name used in error messages when `instanceOf` is a
   * class reference. Needed because the class's own `.name` isn't reliable
   * (bundlers can rename anonymous classes; production builds minify names).
   */
  instanceOfName?: string;
}

/**
 * Schema for a single `childArgs` argument (see `BlockOptions.childArgs`).
 * Extends `ArgSchema` with the child-specific `unique` property.
 */
export interface ChildArgSchema extends ArgSchema {
  /**
   * Whether this arg's value must be unique among sibling children. Only
   * supported for primitive types (string, number, boolean).
   */
  unique?: boolean;
}

/** Options accepted by the `@block` decorator. */
export interface BlockOptions {
  /** If `true`, this block can contain nested child blocks. */
  container?: boolean;

  /** Human-readable description of the block. */
  description?: string;

  /** Schema for the block's arguments, keyed by arg name. */
  args?: Record<string, ArgSchema>;

  /**
   * Schema for args passed to this block's children. Only valid on container
   * blocks (`container: true`).
   */
  childArgs?: Record<string, ChildArgSchema>;

  /** Cross-arg validation constraints. */
  constraints?: BlockConstraints;

  /** Custom validation function run against the block's args. */
  validate?: BlockValidateFn;

  /** Additional CSS classes for the block. */
  classNames?: BlockClassNames;

  /** Glob patterns for the outlets this block is allowed to render in. */
  allowedOutlets?: string[];

  /** Glob patterns for the outlets this block is forbidden from rendering in. */
  deniedOutlets?: string[];
}

/**
 * Frozen metadata recorded for a class decorated with `@block`, returned by
 * `getBlockMetadata()`.
 */
export interface BlockMetadata {
  /** Full name identifier, e.g. `"theme:tactile:hero-banner"`. */
  blockName: string;

  /** Plain name without namespace, e.g. `"hero-banner"`. */
  shortName: string;

  /** Parsed namespace used for CSS, e.g. `"my-plugin"` / `"theme-tactile"`, or `null` for core. */
  namespace: string | null;

  /** The kind of namespace the block belongs to. */
  namespaceType: BlockNamespaceType;

  /** Human-readable description of the block. */
  description: string;

  /** Whether the block can contain nested child blocks. */
  isContainer: boolean;

  /** Additional CSS classes declared on the decorator. */
  decoratorClassNames: BlockClassNames | null;

  /** The block's args schema. */
  args: Record<string, ArgSchema> | null;

  /** The child-args schema (container blocks only). */
  childArgs: Record<string, ChildArgSchema> | null;

  /** Cross-arg validation constraints. */
  constraints: BlockConstraints | null;

  /** Custom validation function. */
  validate: BlockValidateFn | null;

  /** Allowed outlet glob patterns. */
  allowedOutlets: readonly string[] | null;

  /** Denied outlet glob patterns. */
  deniedOutlets: readonly string[] | null;
}

/**
 * A single entry in an outlet layout, as passed to `api.renderBlocks()`.
 */
export interface LayoutEntry {
  /**
   * The block to render: a `@block`-decorated component class, or the string
   * name of a registered block.
   */
  block: typeof Component | string;

  /** Args passed to the block component. */
  args?: Record<string, unknown>;

  /** Additional CSS classes for the block wrapper. */
  classNames?: string | string[];

  /** Nested entries, for container blocks only. */
  children?: LayoutEntry[];

  /** Conditions that must all pass for the block to render. */
  conditions?: object | object[];

  /** Values satisfying the parent container's `childArgs` schema. */
  containerArgs?: Record<string, unknown>;

  /** Unique identifier for targeting and BEM styling. */
  id?: string;
}
