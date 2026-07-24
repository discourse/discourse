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
import type { BlockMetadata, BlockOptions } from "discourse/blocks/types";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import type { BlockClass } from "discourse/lib/blocks/-internals/types";
import {
  validateArgsSchema,
  validateChildArgsSchema,
} from "discourse/lib/blocks/-internals/validation/block-args";
import {
  validateAndParseBlockName,
  validateBlockOptions,
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
    container: isContainer = false,
    classNames: decoratorClassNames = null,
    description = "",
    args: argsSchema = null,
    childArgs: childArgsSchema = null,
    constraints = null,
    validate: validateFn = null,
    allowedOutlets = null,
    deniedOutlets = null,
  } = options;

  // Validate arg schema structure and types.
  validateArgsSchema(argsSchema, name);

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
      childArgs: childArgsSchema ? Object.freeze(childArgsSchema) : null,
      constraints: constraints ? Object.freeze(constraints) : null,
      decoratorClassNames,
      deniedOutlets: deniedOutlets ? Object.freeze([...deniedOutlets]) : null,
      description,
      isContainer,
      namespace: parsed.namespace,
      namespaceType: parsed.type,
      shortName: parsed.name,
      validate: validateFn,
    });

    blockMetadataMap.set(target, metadata);
  };
}

/**
 * Creates the args object for a child block with reactive getters for context
 * args.
 *
 * This embeds the `AUTH_TOKEN` in the `__block$` property, which is how child
 * blocks are authorized to render. Context args are defined as getters rather
 * than direct properties so `curryComponent` can maintain a stable component
 * identity while still updating reactively when the getter values change.
 * Without getters, changing any arg would require a new curried component,
 * breaking Ember's identity-based rendering.
 *
 * @param entryArgs - User-provided args from the layout entry.
 * @param contextArgs - Rendering context to define as reactive getters.
 * @returns The merged args object ready for `curryComponent`.
 */
export function createBlockArgsWithReactiveGetters(
  entryArgs: Record<string, unknown>,
  contextArgs: Record<string, unknown>
): Record<string, unknown> {
  const blockArgs: Record<string, unknown> = {
    ...entryArgs,
    __block$: AUTH_TOKEN,
  };

  // Dynamically define reactive getters for each context arg.
  const propertyDescriptors: PropertyDescriptorMap = {};
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
