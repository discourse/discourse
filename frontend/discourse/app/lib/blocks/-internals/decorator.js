// @ts-check
/**
 * Block Decorator Module
 *
 * This module provides the @block decorator and related authorization utilities.
 * The authorization model uses private symbols and WeakMaps to prevent external
 * code from spoofing block authorization or bypassing validation.
 *
 * Key concepts:
 * - AUTH_TOKEN: A private symbol used to verify authorized block rendering contexts
 * - blockMetadataMap: WeakMap tracking which classes are blocks and their metadata
 * - rootBlockClass: Single variable holding the root block class (set via registerRootBlock)
 *
 * @module discourse/lib/blocks/-internals/decorator
 */
import Component from "@glimmer/component";
import {
  getInternalComponentManager,
  setInternalComponentManager,
  // @ts-ignore - @glimmer/manager types not provided by ember-source
} from "@glimmer/manager";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import {
  validateArgsSchema,
  validateChildArgsSchema,
} from "discourse/lib/blocks/-internals/validation/block-args";
import {
  validateAndParseBlockName,
  validateBlockOptions,
  validateDisplayMetadata,
  validateOutletRestrictions,
} from "discourse/lib/blocks/-internals/validation/block-decorator";
import { validateConstraintsSchema } from "discourse/lib/blocks/-internals/validation/constraints";

/*
 * Authorization System
 *
 * IMPORTANT: These values MUST NOT be exported.
 *
 * The authorization model works as follows:
 * 1. AUTH_TOKEN is a secret symbol known only to this module
 * 2. blockMetadataMap tracks which classes are decorated with @block
 * 3. rootBlockClass holds the single block that can be rendered directly (set via registerRootBlock)
 * 4. Child blocks receive AUTH_TOKEN via the __block$ arg from their parent
 * 5. BlockComponentManager verifies authorization before instantiation
 *
 * This prevents:
 * - Using blocks directly in templates (bypassing BlockOutlet)
 * - Spoofing block authorization by setting properties on classes
 * - Accessing authorization state from external code
 */

/**
 * Secret token used to authorize block rendering.
 * Passed via __block$ arg from parent containers to child blocks.
 */
const AUTH_TOKEN = Symbol("block-auth-token");

/**
 * @typedef {Object} BlockMetadataEntry
 * @property {boolean} isContainer - Whether the block is a container.
 * @property {string} blockName - The block's full name identifier (e.g., "theme:tactile:hero-banner").
 * @property {string} shortName - The block's plain name without namespace (e.g., "hero-banner").
 * @property {string|null} namespace - The parsed namespace for CSS (e.g., "my-plugin" or "theme-tactile").
 * @property {"core"|"plugin"|"theme"} namespaceType - The type of namespace.
 * @property {string} description - Human-readable description of the block.
 * @property {string|string[]|Function|null} decoratorClassNames - CSS classNames from decorator.
 * @property {Object|null} args - Args schema for the block.
 * @property {Object|null} childArgs - Child args schema (containers only).
 * @property {Object|null} constraints - Cross-arg validation constraints.
 * @property {Function|null} validate - Custom validation function.
 * @property {readonly string[]|null} allowedOutlets - Allowed outlet patterns.
 * @property {readonly string[]|null} deniedOutlets - Denied outlet patterns.
 * @property {string|null} displayName - Human-readable name for display
 *   purposes. Falls back to a Title Case of `shortName` when unset (see
 *   `getBlockDisplayMetadata`).
 * @property {string|null} icon - Icon ID associated with the block. Falls
 *   back to `"cube"` when unset.
 * @property {string|null} category - Category label used to group the
 *   block (e.g. "Content", "Layout"). Falls back to `"Misc"` when unset.
 * @property {Readonly<Object>|null} previewArgs - Optional sample args used
 *   when rendering a preview of the block. Frozen shallowly. Falls back to
 *   defaults derived from `args` when unset.
 * @property {string|null} thumbnail - Optional URL of a static thumbnail
 *   image shown instead of the icon.
 * @property {boolean} paletteHidden - When true, the block is excluded from
 *   lists of directly-insertable blocks. The block remains registered and
 *   renderable from layouts that reference it.
 * @property {boolean} transparent - When true, the block is treated as
 *   structural scaffolding rather than a user-facing block (children
 *   expanded inline). See the `transparent` option on `block()`.
 */

/**
 * Maps block classes to their metadata.
 * Using WeakMap ensures:
 * - Classes are garbage collected when no longer referenced
 * - Authorization state cannot be discovered via Object.getOwnPropertySymbols()
 *
 * @type {WeakMap<Function, BlockMetadataEntry>}
 */
const blockMetadataMap = new WeakMap();

/**
 * The single root block class (BlockOutlet).
 * Only one block can be the root - once set, it cannot be changed.
 * This prevents any other block from claiming root status.
 *
 * @type {Function|null}
 */
let rootBlockClass = null;

/**
 * Registers a block class as the root block that can be rendered directly
 * without authorization. Only one root block can be registered.
 *
 * @param {Function} klass - The block class to register as root.
 */
export function registerRootBlock(klass) {
  if (rootBlockClass !== null) {
    raiseBlockError(
      `Only one root block is allowed. ` +
        `"${rootBlockClass.name}" is already registered as the root block.`
    );
  }
  rootBlockClass = klass;
}

/**
 * Custom component manager proxy that enforces block authorization.
 *
 * Blocks can only be instantiated in two authorized scenarios:
 * 1. As a root block - The class is the rootBlockClass (set via registerRootBlock)
 * 2. As a child of a container - The parent passes __block$ arg with AUTH_TOKEN
 *
 * This prevents blocks from being used directly in templates, ensuring they
 * can only be rendered through the BlockOutlet system.
 */
const BlockComponentManager = new Proxy(
  getInternalComponentManager(Component),
  {
    get(target, prop) {
      if (prop === "create") {
        return function (owner, klass, args) {
          // Check if this is the root block (BlockOutlet)
          const isRootBlock = klass === rootBlockClass;

          // Check if this is an authorized child (parent passes __block$ secret token)
          let isAuthorizedChild = false;
          const named = args?.named;
          if (named?.names?.includes("__block$")) {
            const ref = named.get("__block$");
            isAuthorizedChild = ref.compute() === AUTH_TOKEN;
          }

          if (!isRootBlock && !isAuthorizedChild) {
            const blockName =
              blockMetadataMap.get(klass)?.blockName || klass.name;
            throw new Error(
              `Block "${blockName}" cannot be used directly in templates. ` +
                `Blocks can only be rendered inside BlockOutlets or container blocks.`
            );
          }

          return target.create(...arguments);
        };
      }
      return Reflect.get(target, prop);
    },
  }
);

/**
 * Schema for block argument validation.
 *
 * @typedef {Object} ArgSchema
 * @property {"string"|"number"|"boolean"|"array"|"any"} type - The argument type (required)
 * @property {boolean} [required=false] - Whether the argument is required
 * @property {*} [default] - Default value for the argument
 * @property {"string"|"number"|"boolean"} [itemType] - Item type for array arguments
 * @property {RegExp} [pattern] - Regex pattern for string validation
 * @property {number} [minLength] - Minimum length for string or array
 * @property {number} [maxLength] - Maximum length for string or array
 * @property {number} [min] - Minimum value for number
 * @property {number} [max] - Maximum value for number
 * @property {boolean} [integer] - Whether number must be an integer
 * @property {Array} [enum] - Allowed values for the argument
 * @property {Array} [itemEnum] - Allowed values for array items
 * @property {UIHints} [ui] - Optional metadata describing how this arg should
 *   be presented for editing. Pure metadata — has no runtime effect on the
 *   block itself.
 */

/**
 * Optional UI hints describing how an arg should be presented for editing.
 * All fields are advisory — a consumer is free to fall back to a sensible
 * default when a hint is missing. None of these fields affect validation or
 * runtime behaviour of the block.
 *
 * @typedef {Object} UIHints
 * @property {string} [control] - Override the default edit control for
 *   this arg. Valid values are listed in `VALID_UI_CONTROLS` (re-exported
 *   from `discourse/lib/blocks`); examples include "text", "textarea",
 *   "color", "icon", "rich-text", and entity pickers like
 *   "category-select", "tag-select", "user-select", "group-select".
 * @property {string} [label] - Edit-form field label override. Defaults to a
 *   title-cased form of the arg name.
 * @property {string} [placeholder] - Placeholder text for text-style controls.
 * @property {string} [helpText] - Help text shown beneath the control.
 * @property {string} [group] - Edit-form section name (e.g. "Content",
 *   "Appearance"). Args without a group land under "General".
 * @property {boolean} [hidden] - When true, the arg is omitted from the
 *   edit form but kept in the schema (useful for computed args).
 * @property {{arg: string, equals?: *, notEmpty?: boolean}} [conditional] -
 *   Show this field only when another arg satisfies the predicate. At least
 *   one of `equals` or `notEmpty` must be set.
 */

/**
 * Decorator that transforms a Glimmer component into a block component.
 *
 * Block components have special authorization constraints:
 * - They can only be rendered inside BlockOutlets or container blocks
 * - They cannot be used directly in templates
 * - They receive special args for authorization and hierarchy management
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param {string} name - Unique identifier for the block. Supports three namespacing formats:
 *   - Core blocks: `"block-name"` (e.g., "hero-banner", "sidebar-panel")
 *   - Plugin blocks: `"plugin-name:block-name"` (e.g., "my-plugin:custom-card")
 *   - Theme blocks: `"theme:theme-name:block-name"` (e.g., "theme:tactile:hero-section")
 *   Names must use lowercase letters, numbers, and hyphens only.
 *
 * @param {Object} [options] - Configuration options for the block.
 *
 * @param {boolean} [options.container=false] - If true, this block can contain nested child blocks.
 *
 * @param {string} [options.description] - Human-readable description of the block.
 *
 * @param {Object.<string, ArgSchema>} [options.args] - Schema for block arguments.
 *
 * @param {Object.<string, ArgSchema>} [options.childArgs] - Schema for args passed to children
 *   of this container block. Only valid when container: true.
 *
 * @param {Object} [options.constraints] - Cross-arg validation constraints.
 *
 * @param {Function} [options.validate] - Custom validation function.
 *
 * @param {string|string[]|((args: Object) => string)} [options.classNames] - Additional CSS classes.
 *
 * @param {string[]} [options.allowedOutlets] - Glob patterns for allowed outlets.
 *
 * @param {string[]} [options.deniedOutlets] - Glob patterns for denied outlets.
 *
 * @param {string} [options.displayName] - Human-readable name for display
 *   purposes. Defaults to a Title Case of `shortName`.
 *
 * @param {string} [options.icon] - Icon ID associated with the block.
 *   Defaults to `"cube"`.
 *
 * @param {string} [options.category] - Category label for grouping the
 *   block (e.g. `"Content"`, `"Layout"`). Defaults to `"Misc"`.
 *
 * @param {Object} [options.previewArgs] - Sample args used when rendering a
 *   preview of the block. Defaults to a shallow object built from each arg
 *   schema's `default` field.
 *
 * @param {string} [options.thumbnail] - URL of a static thumbnail image
 *   shown instead of the icon.
 *
 * @param {boolean} [options.paletteHidden=false] - When true, the block is
 *   excluded from lists of directly-insertable blocks. The block is still
 *   registered and renderable from layouts that reference it — this hides it
 *   from user-facing inserts only, useful for infrastructure blocks (e.g.
 *   the built-in `group`) and deprecated aliases.
 *
 * @param {boolean} [options.transparent=false] - When true, the block is
 *   treated as structural scaffolding: it is expanded inline (rendering its
 *   children at its own level) and skips the standard block wrapper. Used
 *   for slot-style wrappers that exist solely to attach metadata (e.g. a
 *   slot block carrying CSS Grid placement) without showing up as a
 *   first-class block. Implies — but does not auto-set — `paletteHidden`;
 *   transparent blocks are typically not user-pickable.
 *
 * @returns {Function} Decorator function that returns the decorated class
 *
 * @example
 * // Simple block
 * @block("my-card")
 * class MyCard extends Component { ... }
 *
 * @example
 * // Container block
 * @block("my-section", { container: true })
 * class MySection extends Component { ... }
 *
 */
export function block(name, options = {}) {
  // === Decoration-time validation ===
  validateBlockOptions(name, options);
  const parsed = validateAndParseBlockName(name);

  // Extract all options with defaults
  const {
    container: isContainer = false,
    classNames: decoratorClassNames = null,
    description = "",
    args: argsSchema = null,
    childArgs: childArgsSchema = null,
    constraints = null,
    validate: validateFn = null,
    allowedOutlets = null,
    deniedOutlets = null,
    displayName = null,
    icon = null,
    category = null,
    previewArgs = null,
    thumbnail = null,
    paletteHidden = false,
    transparent = false,
  } = options;

  // Validate arg schema structure and types
  validateArgsSchema(argsSchema, name);

  // Validate childArgs is only allowed on container blocks
  if (childArgsSchema && !isContainer) {
    raiseBlockError(
      `Block "${name}": "childArgs" is only valid for container blocks (container: true).`
    );
  }

  // Validate classNames type (string, array, or function)
  if (
    decoratorClassNames != null &&
    typeof decoratorClassNames !== "string" &&
    typeof decoratorClassNames !== "function" &&
    !Array.isArray(decoratorClassNames)
  ) {
    raiseBlockError(
      `Block "${name}": "classNames" must be a string, array, or function.`
    );
  }

  // Validate childArgs schema structure and types
  validateChildArgsSchema(childArgsSchema, name);

  // Validate constraints schema
  validateConstraintsSchema(constraints, argsSchema, name);

  // Validate that validate is a function if provided
  if (validateFn !== null && typeof validateFn !== "function") {
    raiseBlockError(
      `Block "${name}": "validate" must be a function, got ${typeof validateFn}.`
    );
  }

  // Validate outlet restriction patterns
  validateOutletRestrictions(name, allowedOutlets, deniedOutlets);

  // Shallow type-check the optional display-metadata fields.
  validateDisplayMetadata(name, options);

  return function (target) {
    setInternalComponentManager(BlockComponentManager, target);

    if (!(target.prototype instanceof Component)) {
      raiseBlockError("@block target must be a Glimmer component class");
      return target;
    }

    // Create and register metadata object with all block information
    const metadata = Object.freeze({
      allowedOutlets: allowedOutlets
        ? Object.freeze([...allowedOutlets])
        : null,
      args: argsSchema ? Object.freeze(argsSchema) : null,
      blockName: name,
      category,
      childArgs: childArgsSchema ? Object.freeze(childArgsSchema) : null,
      constraints: constraints ? Object.freeze(constraints) : null,
      decoratorClassNames,
      deniedOutlets: deniedOutlets ? Object.freeze([...deniedOutlets]) : null,
      description,
      displayName,
      icon,
      isContainer,
      namespace: parsed.namespace,
      namespaceType: parsed.type,
      paletteHidden: paletteHidden === true,
      previewArgs: previewArgs ? Object.freeze({ ...previewArgs }) : null,
      shortName: parsed.name,
      thumbnail,
      transparent: transparent === true,
      validate: validateFn,
    });

    blockMetadataMap.set(target, metadata);

    return target;
  };
}

/**
 * Creates the args object for a child block with reactive getters for both
 * the entry's args and the rendering context.
 *
 * This function embeds the AUTH_TOKEN in the __block$ property, which is how
 * child blocks are authorized to render. The token is not exposed - it's
 * embedded in the returned object.
 *
 * Args are defined as reactive getters that read from the LIVE `entry.args`
 * (which is a `trackedObject` after registration in `block-outlet.gjs`).
 * Combined with the compute-ref proxy `curryComponent` builds, this means
 * mutating `entry.args.title = "new"` propagates to the rendered block
 * without re-currying the component or replacing the layout — Glimmer's
 * autotracking reaches in through the proxy to invalidate just the readers
 * of that arg. This is what powers live arg editing.
 *
 * The set of arg KEYS is fixed at curry time (per `curryComponent`'s
 * contract that keys must be static), so adding new args after curry
 * requires a layout replacement. Only value mutations of existing keys
 * propagate reactively.
 *
 * @param {Object} entry - The layout entry. Reads track `entry.args[key]`.
 * @param {Function} ComponentClass - The block's component class. Used to
 *   look up schema defaults for keys not present in `entry.args`.
 * @param {Object} contextArgs - Rendering context (children, outletArgs,
 *   outletName, __hierarchy) defined as static reactive getters.
 * @returns {Object} The merged args object ready for `curryComponent`.
 */
export function createBlockArgsWithReactiveGetters(
  entry,
  ComponentClass,
  contextArgs
) {
  const blockArgs = { __block$: AUTH_TOKEN };

  const schema = blockMetadataMap.get(ComponentClass)?.args ?? {};

  // Union of entry's args and schema keys. The set is frozen at curry time;
  // mutations to existing keys propagate reactively, but adding a new key
  // not anticipated here requires a layout replacement.
  //
  // We deliberately read the cached `entry.__argKeys` (snapshot taken when
  // `assignStableKeys` wrapped the args in a `trackedObject`) instead of
  // calling `Object.keys(entry.args)`. Going through the Proxy's `ownKeys`
  // trap consumes the trackedObject's collection tag — which is dirtied on
  // every `set` (not just add/delete) — and that would invalidate every
  // container's `processedChildren` computation on every keystroke,
  // forcing the whole container subtree to re-curry. The cached snapshot
  // gives us the same key set without opening the dep.
  const argKeys = new Set([
    ...(entry.__argKeys ?? Object.keys(entry.args || {})),
    ...Object.keys(schema),
  ]);

  /** @type {PropertyDescriptorMap} */
  const propertyDescriptors = {};
  for (const key of argKeys) {
    propertyDescriptors[key] = {
      get() {
        const live = entry.args?.[key];
        return live !== undefined ? live : schema[key]?.default;
      },
      enumerable: true,
    };
  }

  // Reactive getters for context args (children, outletArgs, etc.).
  for (const [key, value] of Object.entries(contextArgs)) {
    propertyDescriptors[key] = {
      get() {
        return value;
      },
      enumerable: true,
    };
  }

  Object.defineProperties(blockArgs, propertyDescriptors);

  return blockArgs;
}

/**
 * Gets all metadata for a component registered with @block.
 *
 * Returns a flat object containing all block information:
 * - `blockName` - Full block name (e.g., "theme:my-theme:heading")
 * - `shortName` - Plain name without namespace (e.g., "heading")
 * - `namespace` - Full namespace for CSS ("my-plugin" or "theme-tactile") or null for core
 * - `namespaceType` - "core" | "plugin" | "theme"
 * - `isContainer` - Whether block is a container
 * - `description` - Human-readable description
 * - `decoratorClassNames` - CSS classNames from decorator
 * - `args` - Args schema
 * - `childArgs` - Child args schema (containers only)
 * - `constraints` - Cross-arg validation constraints
 * - `validate` - Custom validation function
 * - `allowedOutlets` - Allowed outlet patterns
 * - `deniedOutlets` - Denied outlet patterns
 * - `displayName` - Display name (or `null` if not provided)
 * - `icon` - Icon ID (or `null` if not provided)
 * - `category` - Category label (or `null` if not provided)
 * - `previewArgs` - Sample args for a preview (or `null`)
 * - `thumbnail` - Thumbnail URL (or `null`)
 * - `paletteHidden` - When true, the block is excluded from lists of directly-insertable blocks
 * - `transparent` - When true, the block is treated as structural scaffolding
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param {Function} component - The component to get metadata for.
 * @returns {Object|null} The block metadata object, or null if not a block.
 */
export function getBlockMetadata(component) {
  return blockMetadataMap.get(component) ?? null;
}
