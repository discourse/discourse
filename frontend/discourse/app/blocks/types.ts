import type Component from "@glimmer/component";
import type Owner from "@ember/owner";
import type { ComponentLike } from "@glint/template";

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
  | "richInline"
  | "image"
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

/**
 * Recognized `ui.control` values, advising which input a block argument should
 * be edited with. Opaque to rendering; consumed by external editing tooling.
 */
export type ArgUiControl =
  | "text"
  | "textarea"
  | "number"
  | "toggle"
  | "select"
  | "radio-group"
  | "color"
  | "icon"
  | "emoji"
  | "url"
  | "rich-text"
  | "rich-inline"
  | "code"
  | "category-select"
  | "tag-select"
  | "user-select"
  | "group-select"
  | "topic-select"
  | "repeatable"
  | "dimension"
  | "stepper"
  | "segmented";

/**
 * A predicate gating an argument's edit-form visibility on another argument's
 * value.
 */
export interface ArgUiConditional {
  /** The sibling argument whose value is inspected. */
  arg: string;

  /** Passes when the sibling argument equals this value. */
  equals?: unknown;

  /** Passes when the sibling argument is non-empty. */
  notEmpty?: boolean;
}

/**
 * Edit-form presentation hints for a block argument. Entirely opaque to
 * rendering; consumed only by external editing tooling.
 */
export interface ArgUiHint {
  /** Which input the argument is edited with. */
  control?: ArgUiControl;

  /** Field label. */
  label?: string;

  /** Placeholder text for the input. */
  placeholder?: string;

  /** Help text shown alongside the field. */
  helpText?: string;

  /** Prompt shown when the value is empty. */
  emptyPrompt?: string;

  /** Grouping label for organizing fields. */
  group?: string;

  /** Whether the field is hidden from the edit form. */
  hidden?: boolean;

  /** Predicate gating the field's visibility on another argument's value. */
  conditional?: ArgUiConditional;

  /** Per-option icons, keyed by option value (for enum-style controls). */
  optionIcons?: Record<string, string>;

  /** Variant hint for a rich-inline argument; opaque to the core validator. */
  schema?: string;

  /** Allowed units a numeric value may carry. */
  units?: string[];

  /** Default unit for a numeric value. */
  unit?: string;

  /** Increment step for a numeric value. */
  step?: number;

  /** Whether to show an inline slider for a numeric value. */
  slider?: boolean;
}

/** Schema describing and validating a single block argument. */
export interface ArgSchema {
  /** The argument's value type. */
  type: ArgType;

  /** Whether the argument must be provided. Defaults to `false`. */
  required?: boolean;

  /** Default value applied when the argument is omitted. */
  default?: unknown;

  /** Element type for `array` arguments. */
  itemType?: "string" | "number" | "boolean" | "object";

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
   * Nested schema for the items of an `array` argument whose `itemType` is
   * `"object"`, validated recursively against each item.
   */
  itemSchema?: Record<string, ArgSchema>;

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

  /** Edit-form presentation hints. Opaque to rendering. */
  ui?: ArgUiHint;

  /** For an image argument: whether a dark-scheme variant may be supplied. */
  allowDark?: boolean;

  /** For an image argument: whether the image may be resized. */
  allowResize?: boolean;

  /** For an image argument: the aspect ratio to constrain the image to. */
  aspectRatio?: string | number;

  /**
   * For an image argument: the default `object-fit` behavior when the image is
   * sized by its container.
   */
  defaultFit?: "cover" | "contain" | "fill";
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

/**
 * A loading-skeleton descriptor a data-driven block returns to shape its
 * placeholder while data resolves.
 */
export interface BlockSkeletonShape {
  /** Skeleton style variant. */
  variant?: string;

  /** Number of skeleton rows/items to paint. */
  count?: number;

  /** Explicit skeleton width. */
  width?: string;

  /** Explicit skeleton height. */
  height?: string;
}

/**
 * A block's declared data dependency: how to build the request descriptor,
 * resolve it (optionally aborting via a signal), optionally hydrate a raw
 * payload, and shape the loading skeleton. Consumed by the render pipeline's
 * data boundary.
 */
export interface BlockDataDeclaration {
  /** Builds the request descriptor from the block's args. */
  request: (args?: Record<string, unknown> | null) => unknown;

  /** Resolves the descriptor to the block's data. */
  resolve: (
    descriptor: unknown,
    options: { owner?: Owner; signal?: AbortSignal }
  ) => unknown;

  /** Optionally hydrates a raw payload into the resolved shape. */
  hydrate?: (raw: unknown, options: { owner?: Owner }) => unknown;

  /** Shapes the loading skeleton painted while data resolves. */
  skeleton?: (args?: Record<string, unknown> | null) => BlockSkeletonShape;
}

/**
 * A block's selection/preview thumbnail: an icon ID, a light/dark image pair, a
 * component, or a lazy loader returning one. Consumed by external tooling.
 */
export type BlockThumbnail =
  | string
  | { light: string; dark?: string }
  | ComponentLike
  | (() => Promise<ComponentLike | { default: ComponentLike }>);

/**
 * A composite block part, as declared in `@block({ parts: [...] })`. A part is
 * a nested block instance the composite renders in place of authored children.
 */
export interface BlockPartDefinition {
  /** Stable identifier for the part, used to address per-part overrides. */
  id: string;

  /** The part's block: a `@block`-decorated class or a registered block name. */
  block: typeof Component | string;

  /** Args applied to the part. */
  args?: Record<string, unknown>;

  /**
   * Which of the part's args are locked from override: `true` locks all, or a
   * list of arg names.
   */
  lock?: true | string[];
}

/** A frozen composite part recorded in {@link BlockMetadata.parts}. */
export interface BlockPart {
  /** Stable identifier for the part. */
  id: string;

  /** The part's block: a `@block`-decorated class or a registered block name. */
  block: typeof Component | string;

  /** Args applied to the part, or `null` when none were declared. */
  args: Readonly<Record<string, unknown>> | null;

  /** Locked args: `true` locks all, a list of arg names, or `null` for none. */
  lock: true | readonly string[] | null;
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

  /** Names of the blocks this container permits as direct children. */
  childBlocks?: string[];

  /** Human-readable label for display purposes (e.g. in a selection listing). */
  displayName?: string;

  /** Icon ID representing the block. */
  icon?: string;

  /** Grouping label for organizing blocks. */
  category?: string;

  /** Example args used to render a preview of the block. */
  previewArgs?: Record<string, unknown>;

  /** Selection/preview thumbnail for the block. */
  thumbnail?: BlockThumbnail;

  /** When `true`, the block is omitted from block-selection listings. */
  paletteHidden?: boolean;

  /** When `true`, the block renders without its own wrapper element. */
  transparent?: boolean;

  /** When `true`, the block's grid placement can be edited. */
  gridEditable?: boolean;

  /** The block's declared data dependency. */
  data?: BlockDataDeclaration;

  /** Composite parts synthesized as the block's children at render time. */
  parts?: BlockPartDefinition[];
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

  /** Grouping label, or `null` when none was declared. */
  category: string | null;

  /** Names of permitted direct child blocks, or `null` for no restriction. */
  childBlocks: readonly string[] | null;

  /** The block's declared data dependency, or `null` when none. */
  data: Readonly<BlockDataDeclaration> | null;

  /** Human-readable display label, or `null` when none was declared. */
  displayName: string | null;

  /** Icon ID, or `null` when none was declared. */
  icon: string | null;

  /** Whether the block's grid placement can be edited. */
  gridEditable: boolean;

  /** Whether the block is omitted from block-selection listings. */
  paletteHidden: boolean;

  /** Frozen composite parts, or `null` when the block declares none. */
  parts: readonly BlockPart[] | null;

  /** Example preview args, or `null` when none were declared. */
  previewArgs: Readonly<Record<string, unknown>> | null;

  /** Selection/preview thumbnail, or `null` when none was declared. */
  thumbnail: BlockThumbnail | null;

  /** Whether the block renders without its own wrapper element. */
  transparent: boolean;
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

  /**
   * Per-part overrides for a composite block, keyed by part path. Consumed by
   * the composite renderer to apply arg/attribute overrides onto synthesized
   * parts.
   */
  overrides?: Record<string, unknown>;
}

/**
 * The data-region boundary the framework curries onto a data-driven block as
 * `@Data`. A block wraps the data-dependent part of its template in `<@Data>`
 * and supplies the named blocks below; the framework paints the loading
 * skeleton and inline error by default.
 *
 * The `Value` type parameter is the shape the block's `data.resolve` produces,
 * so `<:content as |value|>` is typed for the specific block.
 *
 * @typeParam Value - The resolved data yielded to the `content` block.
 */
export type BlockDataComponent<Value = unknown> = ComponentLike<{
  Blocks: {
    content: [value: Value];
    loading: [];
    error: [];
    empty: [];
  };
}>;
