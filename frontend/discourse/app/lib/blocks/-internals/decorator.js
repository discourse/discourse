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
 * - rootBlockClass: Single variable holding the root block class (BlockOutlet)
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
 * 3. rootBlockClass holds the single block that can be rendered directly (BlockOutlet)
 * 4. Child blocks receive AUTH_TOKEN via the $block$ arg from their parent
 * 5. BlockComponentManager verifies authorization before instantiation
 *
 * This prevents:
 * - Using blocks directly in templates (bypassing BlockOutlet)
 * - Spoofing block authorization by setting properties on classes
 * - Accessing authorization state from external code
 */

/**
 * Secret token used to authorize block rendering.
 * Passed via $block$ arg from parent containers to child blocks.
 */
const AUTH_TOKEN = Symbol("block-auth-token");

/**
 * Maps block classes to their metadata.
 * Using WeakMap ensures:
 * - Classes are garbage collected when no longer referenced
 * - Authorization state cannot be discovered via Object.getOwnPropertySymbols()
 *
 * @type {WeakMap<Function, { isContainer: boolean }>}
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
 * Custom component manager proxy that enforces block authorization.
 *
 * Blocks can only be instantiated in two authorized scenarios:
 * 1. As a root block - The class is the rootBlockClass (marked with root: true in decorator)
 * 2. As a child of a container - The parent passes $block$ arg with AUTH_TOKEN
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

          // Check if this is an authorized child (parent passes $block$ secret token)
          let isAuthorizedChild = false;
          const named = args?.named;
          if (named?.names?.includes("$block$")) {
            const ref = named.get("$block$");
            isAuthorizedChild = ref.compute() === AUTH_TOKEN;
          }

          if (!isRootBlock && !isAuthorizedChild) {
            throw new Error(
              `Block "${klass.blockName || klass.name}" cannot be used directly in templates. ` +
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
 * @param {boolean} [options.root=false] - If true, this block can be rendered directly without
 *   authorization. Only BlockOutlet should use this option.
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
 * @example
 * // Root block (only for BlockOutlet)
 * @block("block-outlet", { container: true, root: true })
 * class BlockOutlet extends Component { ... }
 */
export function block(name, options = {}) {
  // === Decoration-time validation ===
  validateBlockOptions(name, options);
  const parsed = validateAndParseBlockName(name);

  // Extract all options with defaults
  const isContainer = options.container ?? false;
  const isRoot = options.root ?? false;
  const decoratorClassNames = options.classNames ?? null;
  const description = options.description ?? "";
  const argsSchema = options.args ?? null;
  const childArgsSchema = options.childArgs ?? null;
  const constraints = options.constraints ?? null;
  const validateFn = options.validate ?? null;
  const allowedOutlets = options.allowedOutlets ?? null;
  const deniedOutlets = options.deniedOutlets ?? null;

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

  // Create metadata object once (returned by getter)
  const metadata = Object.freeze({
    description,
    container: isContainer,
    decoratorClassNames,
    args: argsSchema ? Object.freeze(argsSchema) : null,
    childArgs: childArgsSchema ? Object.freeze(childArgsSchema) : null,
    constraints: constraints ? Object.freeze(constraints) : null,
    validate: validateFn,
    allowedOutlets: allowedOutlets ? Object.freeze([...allowedOutlets]) : null,
    deniedOutlets: deniedOutlets ? Object.freeze([...deniedOutlets]) : null,
  });

  return function (target) {
    setInternalComponentManager(BlockComponentManager, target);

    if (!(target.prototype instanceof Component)) {
      raiseBlockError("@block target must be a Glimmer component class");
      return target;
    }

    // Register block in WeakMap (replaces setting symbols on class)
    blockMetadataMap.set(target, { isContainer });

    // Mark as root block if specified - only one root block is allowed (BlockOutlet)
    if (isRoot) {
      if (rootBlockClass !== null) {
        raiseBlockError(
          `Block "${name}": Only one root block is allowed. ` +
            `"${rootBlockClass.name}" is already registered as the root block.`
        );
      }
      rootBlockClass = target;
    }

    // Define instance getter for block name on the prototype
    Object.defineProperty(target.prototype, "name", {
      get: () => name,
      configurable: false,
    });

    // Define static getters on the class
    Object.defineProperties(target, {
      blockName: {
        get: () => name,
        configurable: false,
      },
      namespace: {
        get: () => parsed.namespace,
        configurable: false,
      },
      namespaceType: {
        get: () => parsed.type,
        configurable: false,
      },
      blockMetadata: {
        get: () => metadata,
        configurable: false,
      },
    });

    return target;
  };
}

/**
 * Creates the args object for a child block with reactive getters for context args.
 *
 * This function embeds the AUTH_TOKEN in the $block$ property, which is how
 * child blocks are authorized to render. The token is not exposed - it's
 * embedded in the returned object.
 *
 * Context args are defined as getters rather than direct properties. This allows
 * `curryComponent` to maintain a stable component identity while enabling reactive
 * updates when the getter values change. Without getters, changing any arg would
 * require creating a new curried component, breaking Ember's identity-based rendering.
 *
 * @param {Object} entryArgs - User-provided args from the layout entry.
 * @param {Object} contextArgs - Rendering context to define as reactive getters.
 * @returns {Object} The merged args object ready for `curryComponent`.
 */
export function createBlockArgsWithReactiveGetters(entryArgs, contextArgs) {
  const blockArgs = {
    ...entryArgs,
    $block$: AUTH_TOKEN,
  };

  // Dynamically define reactive getters for each context arg
  /** @type {PropertyDescriptorMap} */
  const propertyDescriptors = {};
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
 * Checks if a component is registered as a block.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param {Function} component - The component to check
 * @returns {boolean} True if the component is registered as a block, false otherwise
 */
export function _isBlock(component) {
  return blockMetadataMap.has(component);
}

/**
 * Checks if a component is registered as a container block.
 *
 * Note: This function is exported for validation but should not be used
 * to bypass block rendering authorization.
 * It only returns a boolean, not the internal authorization state.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param {Function} component - The component to check
 * @returns {boolean} True if the component is registered as a container block, false otherwise
 */
export function _isContainerBlock(component) {
  return blockMetadataMap.get(component)?.isContainer ?? false;
}
