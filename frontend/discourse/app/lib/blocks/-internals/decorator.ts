/**
 * Block Decorator Module
 *
 * This module provides the `@block` decorator and related authorization
 * utilities. The authorization model uses private symbols and WeakMaps to
 * prevent external code from spoofing block authorization or bypassing
 * validation.
 *
 * Key concepts:
 * - `AUTH_TOKEN`: a private symbol used to verify authorized block rendering contexts.
 * - `blockMetadataMap`: a WeakMap tracking which classes are blocks and their metadata.
 * - `rootBlockClass`: a single variable holding the root block class (set via `registerRootBlock`).
 */
import Component from "@glimmer/component";
import {
  getInternalComponentManager,
  setInternalComponentManager,
} from "@glimmer/manager";
import type {
  ArgSchema,
  BlockMetadata,
  BlockOptions,
} from "discourse/blocks/types";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import type { BlockClass } from "discourse/lib/blocks/-internals/types";
import {
  validateArgsSchema,
  validateChildArgsSchema,
} from "discourse/lib/blocks/-internals/validation/block-args";
import {
  validateAndParseBlockName,
  validateBlockDataOption,
  validateBlockOptions,
  validateBlockParts,
  validateChildBlocks,
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
 * 1. AUTH_TOKEN is a secret symbol known only to this module.
 * 2. blockMetadataMap tracks which classes are decorated with @block.
 * 3. rootBlockClass holds the single block that can be rendered directly (set via registerRootBlock).
 * 4. Child blocks receive AUTH_TOKEN via the __block$ arg from their parent.
 * 5. BlockComponentManager verifies authorization before instantiation.
 *
 * This prevents:
 * - Using blocks directly in templates (bypassing BlockOutlet).
 * - Spoofing block authorization by setting properties on classes.
 * - Accessing authorization state from external code.
 */

/**
 * Secret token used to authorize block rendering. Passed via the `__block$` arg
 * from parent containers to child blocks.
 */
const AUTH_TOKEN = Symbol("block-auth-token");

/**
 * The minimal surface of Glimmer's internal component manager that this module
 * relies on. Wrapped in a Proxy to enforce block authorization on `create`.
 */
interface InternalManager {
  create(...args: unknown[]): unknown;
}

/**
 * The captured named-args reference Glimmer passes to `create`. Only the members
 * needed to read the `__block$` authorization token are described.
 */
interface CapturedArgs {
  named?: {
    names: string[];
    get(name: string): { compute(): unknown };
  };
}

/**
 * Maps block classes to their metadata. A WeakMap ensures classes are garbage
 * collected when no longer referenced and that authorization state cannot be
 * discovered via `Object.getOwnPropertySymbols()`. The key is widened to
 * `object` (rather than a block-class type) because the registry probes it with
 * lazy block factory functions too, and both classes and factories are objects.
 */
const blockMetadataMap = new WeakMap<object, BlockMetadata>();

/**
 * The single root block class (BlockOutlet). Only one block can be the root;
 * once set it cannot be changed, which prevents any other block from claiming
 * root status.
 */
let rootBlockClass: BlockClass | null = null;

/**
 * Registers a block class as the root block that can be rendered directly
 * without authorization. Only one root block can be registered.
 *
 * @param klass - The block class to register as the root.
 */
export function registerRootBlock(klass: BlockClass): void {
  if (rootBlockClass !== null) {
    // `BlockClass` is a construct signature, so `.name` (a runtime Function
    // static) is read through a cast.
    const existingName = (rootBlockClass as { name: string }).name;
    raiseBlockError(
      `Only one root block is allowed. ` +
        `"${existingName}" is already registered as the root block.`
    );
  }
  rootBlockClass = klass;
}

/**
 * Custom component-manager proxy that enforces block authorization. Blocks can
 * only be instantiated in two authorized scenarios:
 * 1. As the root block (the class is `rootBlockClass`, set via `registerRootBlock`).
 * 2. As a child of a container (the parent passes the `__block$` arg with `AUTH_TOKEN`).
 *
 * This prevents blocks from being used directly in templates, ensuring they can
 * only be rendered through the BlockOutlet system.
 */
const baseManager = getInternalComponentManager(Component) as InternalManager;

const BlockComponentManager = new Proxy(baseManager, {
  get(target, prop) {
    if (prop === "create") {
      // Glimmer calls `create` with more positional args than the three we
      // inspect (env, dynamic scope, caller, ...). Capture them all with a rest
      // param and forward the full list so no rendering context is dropped.
      return function (...createArgs: unknown[]): unknown {
        const klass = createArgs[1] as BlockClass;
        const args = createArgs[2] as CapturedArgs;

        // Check if this is the root block (BlockOutlet).
        const isRootBlock = klass === rootBlockClass;

        // Check if this is an authorized child (parent passes __block$ secret token).
        let isAuthorizedChild = false;
        const named = args?.named;
        if (named?.names?.includes("__block$")) {
          const ref = named.get("__block$");
          isAuthorizedChild = ref.compute() === AUTH_TOKEN;
        }

        if (!isRootBlock && !isAuthorizedChild) {
          const blockName =
            blockMetadataMap.get(klass)?.blockName ||
            (klass as { name: string }).name;
          throw new Error(
            `Block "${blockName}" cannot be used directly in templates. ` +
              `Blocks can only be rendered inside BlockOutlets or container blocks.`
          );
        }

        return target.create(...createArgs);
      };
    }
    return Reflect.get(target, prop);
  },
});

/**
 * Deeply freezes a validated `parts` composition for storage on block metadata,
 * so the code-defined defaults can't be mutated at runtime. Freezes the array,
 * each part, and each part's `args` and `lock`.
 *
 * @param parts - The validated parts array.
 * @returns The frozen parts.
 */
function freezeParts(
  parts: NonNullable<BlockOptions["parts"]>
): NonNullable<BlockMetadata["parts"]> {
  return Object.freeze(
    parts.map((part) =>
      Object.freeze({
        ...part,
        args: part.args ? Object.freeze({ ...part.args }) : null,
        lock: Array.isArray(part.lock)
          ? Object.freeze([...part.lock])
          : (part.lock ?? null),
      })
    )
  );
}

/**
 * Decorator that transforms a Glimmer component into a block component.
 *
 * Block components have special authorization constraints:
 * - They can only be rendered inside BlockOutlets or container blocks.
 * - They cannot be used directly in templates.
 * - They receive special args for authorization and hierarchy management.
 *
 * @experimental This API is under active development and may change or be
 * removed in future releases without prior notice.
 *
 * @param name - Unique identifier for the block. Supports three namespacing
 *   formats: core blocks `"block-name"`, plugin blocks `"plugin-name:block-name"`,
 *   and theme blocks `"theme:theme-name:block-name"`. Names must use lowercase
 *   letters, numbers, and hyphens only.
 * @param options - Configuration options for the block (see `BlockOptions`).
 * @returns A decorator that returns the decorated class.
 *
 * @example
 * ```js
 * @block("my-card")
 * class MyCard extends Component {}
 *
 * @block("my-section", { container: true })
 * class MySection extends Component {}
 * ```
 */
export function block(
  name: string,
  options: BlockOptions = {}
): ClassDecorator {
  // Decoration-time validation.
  validateBlockOptions(name, options);
  const parsed = validateAndParseBlockName(name);

  const {
    container: containerOption = false,
    classNames: decoratorClassNames = null,
    description = "",
    args: argsSchema = null,
    childArgs: childArgsSchema = null,
    childBlocks = null,
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
    gridEditable = false,
    data: dataDeclaration = null,
    parts = null,
  } = options;

  // A block that declares a `parts` composition renders inner blocks, so it
  // behaves as a container (it yields children) regardless of the explicit
  // `container` flag. When such an entry supplies its own `children` it is
  // treated as a plain container instead (the composition is bypassed).
  const isContainer = containerOption === true || parts != null;

  // Validate the optional inner composition.
  validateBlockParts(name, parts);

  // Validate arg schema structure and types.
  validateArgsSchema(argsSchema, name);

  // Validate the optional coordinated data declaration.
  validateBlockDataOption(name, dataDeclaration);

  // `data` is a reserved arg name: the layout wrapper injects the block's
  // resolved data as `@data`, so a same-named entry in the args schema would
  // collide with it.
  if (argsSchema && Object.prototype.hasOwnProperty.call(argsSchema, "data")) {
    raiseBlockError(
      `Block "${name}": "data" is a reserved arg name (the resolved data ` +
        `dependency is injected as @data); rename the arg.`
    );
  }

  // childArgs is only allowed on container blocks.
  if (childArgsSchema && !isContainer) {
    raiseBlockError(
      `Block "${name}": "childArgs" is only valid for container blocks (container: true).`
    );
  }

  // classNames must be a string, array, or function.
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

  // Validate childArgs schema structure and types.
  validateChildArgsSchema(childArgsSchema, name);

  // Validate constraints schema.
  validateConstraintsSchema(constraints, argsSchema, name);

  // validate must be a function if provided.
  if (validateFn !== null && typeof validateFn !== "function") {
    raiseBlockError(
      `Block "${name}": "validate" must be a function, got ${typeof validateFn}.`
    );
  }

  // Validate outlet restriction patterns.
  validateOutletRestrictions(name, allowedOutlets, deniedOutlets);

  // Validate the optional child-block allow-list.
  validateChildBlocks(name, childBlocks, isContainer);

  // Shallow type-check the optional display-metadata fields.
  validateDisplayMetadata(name, options);

  // A legacy class decorator that returns nothing keeps the class unchanged,
  // which is exactly what this decorator wants — it records metadata and
  // installs a component manager as side effects rather than replacing the
  // class, so there is no need to return the target.
  return (target) => {
    setInternalComponentManager(BlockComponentManager, target);

    if (!(target.prototype instanceof Component)) {
      raiseBlockError("@block target must be a Glimmer component class");
      return;
    }

    // Create and register the frozen metadata object with all block information.
    const metadata: BlockMetadata = Object.freeze({
      allowedOutlets: allowedOutlets
        ? Object.freeze([...allowedOutlets])
        : null,
      args: argsSchema ? Object.freeze(argsSchema) : null,
      blockName: name,
      category,
      childArgs: childArgsSchema ? Object.freeze(childArgsSchema) : null,
      childBlocks: childBlocks ? Object.freeze([...childBlocks]) : null,
      constraints: constraints ? Object.freeze(constraints) : null,
      data: dataDeclaration ? Object.freeze({ ...dataDeclaration }) : null,
      decoratorClassNames,
      deniedOutlets: deniedOutlets ? Object.freeze([...deniedOutlets]) : null,
      description,
      displayName,
      icon,
      isContainer,
      gridEditable: gridEditable === true,
      namespace: parsed.namespace,
      namespaceType: parsed.type,
      paletteHidden: paletteHidden === true,
      parts: parts ? freezeParts(parts) : null,
      previewArgs: previewArgs ? Object.freeze({ ...previewArgs }) : null,
      shortName: parsed.name,
      thumbnail,
      transparent: transparent === true,
      validate: validateFn,
    });

    blockMetadataMap.set(target, metadata);
  };
}

/**
 * Creates the args object for a child block with reactive getters for both the
 * entry's args and the rendering context.
 *
 * This function embeds the `AUTH_TOKEN` in the `__block$` property, which is how
 * child blocks are authorized to render. The token is not exposed - it's
 * embedded in the returned object.
 *
 * Args are defined as reactive getters that read from the LIVE `entry.args`
 * (which is a tracked object after registration in the render pipeline).
 * Combined with the compute-ref proxy `curryComponent` builds, this means
 * mutating `entry.args.title = "new"` propagates to the rendered block without
 * re-currying the component or replacing the layout — Glimmer's autotracking
 * reaches in through the proxy to invalidate just the readers of that arg. This
 * is what powers in-session arg editing.
 *
 * The set of arg KEYS is fixed at curry time (per `curryComponent`'s contract
 * that keys must be static), so adding new args after curry requires a layout
 * replacement. Only value mutations of existing keys propagate reactively.
 *
 * @param entry - The layout entry. Reads track `entry.args[key]`.
 * @param ComponentClass - The block's component class. Used to look up schema
 *   defaults for keys not present in `entry.args`.
 * @param contextArgs - Rendering context (children, outletArgs, outletName,
 *   __hierarchy) defined as static reactive getters.
 * @returns The merged args object ready for `curryComponent`.
 */
export function createBlockArgsWithReactiveGetters(
  entry: { args?: Record<string, unknown>; __argKeys?: string[] },
  ComponentClass: BlockClass,
  contextArgs: Record<string, unknown>
): Record<string, unknown> {
  const blockArgs: Record<string, unknown> = { __block$: AUTH_TOKEN };

  const schema: Record<string, ArgSchema> =
    blockMetadataMap.get(ComponentClass)?.args ?? {};

  // Union of the entry's args and schema keys. The set is frozen at curry time;
  // mutations to existing keys propagate reactively, but adding a new key not
  // anticipated here requires a layout replacement.
  //
  // We deliberately read the cached `entry.__argKeys` (a snapshot taken when
  // the args were wrapped in a tracked object) instead of calling
  // `Object.keys(entry.args)`. Going through the Proxy's `ownKeys` trap
  // consumes the tracked object's collection tag — which is dirtied on every
  // `set` (not just add/delete) — and that would invalidate every container's
  // processed-children computation on every keystroke, forcing the whole
  // container subtree to re-curry. The cached snapshot gives us the same key
  // set without opening that dependency.
  const argKeys = new Set<string>([
    ...(entry.__argKeys ?? Object.keys(entry.args ?? {})),
    ...Object.keys(schema),
  ]);

  const propertyDescriptors: PropertyDescriptorMap = {};
  for (const key of argKeys) {
    propertyDescriptors[key] = {
      get() {
        const live = entry.args?.[key];
        return live !== undefined ? live : schema[key]?.default;
      },
      enumerable: true,
    };
  }

  // Reactive getters for context args (children, outletArgs, etc.). A static
  // value is returned as-is; a function value is used directly as the getter
  // body. The function form lets a caller back a context arg with live state —
  // e.g. a container's `children` reads from a tracked holder, so a cached
  // (persisted) container observes freshly processed children without being
  // re-curried. The getter must read tracked state for this to be reactive:
  // the curry's compute-ref only re-pulls an arg when a tag read inside its
  // getter dirties.
  for (const [key, value] of Object.entries(contextArgs)) {
    propertyDescriptors[key] = {
      get: typeof value === "function" ? (value as () => unknown) : () => value,
      enumerable: true,
    };
  }

  Object.defineProperties(blockArgs, propertyDescriptors);

  return blockArgs;
}

/**
 * Gets all metadata for a component registered with `@block`.
 *
 * @experimental This API is under active development and may change or be
 * removed in future releases without prior notice.
 *
 * @param component - The component (or factory) to get metadata for.
 * @returns The block metadata object, or `null` if not a block.
 */
export function getBlockMetadata(component: object): BlockMetadata | null {
  return blockMetadataMap.get(component) ?? null;
}
