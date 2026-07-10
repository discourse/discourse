// @ts-check
/**
 * Outlet layout validation utilities.
 *
 * This module provides validation for outlet layouts passed to renderBlocks().
 * It validates block entries, container/children relationships, args against
 * block schemas, and conditions.
 *
 * Terminology:
 * - **Block Entry**: An object in a layout that specifies how to use a block.
 * - **Outlet Layout**: An array of block entries defining which blocks appear in an outlet.
 *
 * @module discourse/lib/blocks/-internals/validation/layout
 */

import { DEBUG } from "@glimmer/env";
import { getOwner } from "@ember/owner";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import {
  BlockError,
  raiseBlockError,
} from "discourse/lib/blocks/-internals/error";
import { isBlockPermittedInOutlet } from "discourse/lib/blocks/-internals/matching/outlet-matcher";
import {
  MAX_LAYOUT_DEPTH,
  OPTIONAL_MISSING,
  parseBlockReference,
  VALID_BLOCK_ID_PATTERN,
} from "discourse/lib/blocks/-internals/patterns";
import {
  hasBlock,
  isBlockResolved,
  resolveBlock,
  tryResolveBlock,
} from "discourse/lib/blocks/-internals/registry/block";
import {
  getAllOutlets,
  isValidOutlet,
} from "discourse/lib/blocks/-internals/registry/outlet";
import {
  applyArgDefaults,
  buildErrorPath,
  createValidationContext,
} from "discourse/lib/blocks/-internals/utils";
import { validateArgsAgainstSchema } from "discourse/lib/blocks/-internals/validation/args";
import { validateBlockArgs } from "discourse/lib/blocks/-internals/validation/block-args";
import {
  runCustomValidation,
  validateConstraints,
} from "discourse/lib/blocks/-internals/validation/constraints";
import { ERROR_CODES } from "discourse/lib/blocks/-internals/validation/error-codes";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * Wraps a validation function call with BlockError handling.
 * Catches errors with a `path` property and re-raises with full context.
 *
 * @param {Function} validationFn - The validation function to call.
 * @param {string} errorPrefix - Prefix for the error message.
 * @param {Object} context - Error context including outletName, blockName, path, etc.
 */
function wrapValidationError(validationFn, errorPrefix, context) {
  try {
    validationFn();
  } catch (error) {
    // Errors with path property need context enrichment
    if (error.path) {
      raiseBlockError(`${errorPrefix}: ${error.message}`, {
        ...context,
        errorPath: buildErrorPath(context.path, error.path),
        // Preserve the structured payload through the re-throw. Without
        // this, args-validation throws lose `code` / `field` / `expected`
        // by the time a consumer catches the wrapped error.
        details: error.details ?? null,
      });
    }
    throw error;
  }
}

/**
 * Validates that a block is permitted in the specified outlet.
 * Checks allowedOutlets and deniedOutlets metadata if present.
 *
 * @param {Object} metadata - Block metadata with outlet restrictions.
 * @param {string} outletName - The outlet being validated.
 * @param {string} blockName - The block name for error messages.
 * @param {Object} context - Error context for raiseBlockError.
 * @returns {boolean} True if validation passed, false if error was raised.
 */
function validateOutletPermission(metadata, outletName, blockName, context) {
  if (!metadata?.allowedOutlets && !metadata?.deniedOutlets) {
    return true;
  }

  const permission = isBlockPermittedInOutlet(
    outletName,
    metadata.allowedOutlets,
    metadata.deniedOutlets
  );

  if (!permission.permitted) {
    raiseBlockError(
      `Block "${blockName}" at ${context.path} cannot be rendered in outlet "${outletName}": ${permission.reason}.`,
      context
    );
    return false;
  }
  return true;
}

/**
 * Validates container/children relationship.
 * Containers must have children, non-containers cannot have children.
 *
 * A composite block (one that declares `parts`) is the exception: it is a
 * container, but its children are synthesized from its parts at render time,
 * so a valid instance carries no explicit `children`. Declared parts therefore
 * satisfy the "must have children" requirement.
 *
 * @param {Object} entry - The block entry.
 * @param {boolean} isContainer - Whether the block is a container.
 * @param {boolean} hasParts - Whether the block declares composite `parts`.
 * @param {string} blockName - The block name for error messages.
 * @param {string} outletName - The outlet name for error messages.
 * @param {Object} context - Error context for raiseBlockError.
 * @returns {boolean} True if validation passed, false if error was raised.
 */
function validateContainerChildren(
  entry,
  isContainer,
  hasParts,
  blockName,
  outletName,
  context
) {
  const hasChildren = entry.children?.length > 0;

  if (hasChildren && !isContainer) {
    raiseBlockError(
      `Block component ${blockName} in layout ${outletName} cannot have children`,
      {
        ...context,
        details: {
          code: ERROR_CODES.INVALID_CHILDREN,
          expected: { acceptsChildren: false },
        },
      }
    );
    return false;
  }

  if (isContainer && !hasChildren && !hasParts) {
    raiseBlockError(
      `Block component ${blockName} in layout ${outletName} must have children`,
      {
        ...context,
        details: {
          code: ERROR_CODES.INVALID_CHILDREN,
          expected: { acceptsChildren: true, requiresChildren: true },
        },
      }
    );
    return false;
  }
  return true;
}

/**
 * Resolves a child entry's block reference to its registered name, accepting
 * either a string name (the common case, and the only thing available for an
 * unresolved factory) or a resolved `@block`-decorated class. Returns null when
 * the name can't be determined, so the caller stays permissive in that case.
 *
 * @param {string|Function} blockRef - A child entry's `block` value.
 * @returns {string|null}
 */
function childBlockName(blockRef) {
  if (typeof blockRef === "string") {
    return blockRef;
  }
  if (blockRef) {
    return getBlockMetadata(blockRef)?.blockName ?? null;
  }
  return null;
}

/**
 * Validates a container's direct children against its `childBlocks` allow-list.
 * When the parent declares `childBlocks`, every direct child's block name must
 * appear in the list. The check is name-based — it reads each child's name
 * directly (string, or the resolved class's `blockName`) and never needs the
 * child's class resolved — so it holds even for unresolved child factories; it
 * only relies on the parent (already resolved here) carrying the allow-list.
 *
 * No-ops (returns true) when the parent declares no `childBlocks`. A child whose
 * name can't be determined is skipped rather than rejected.
 *
 * @param {Object} entry - The parent container entry.
 * @param {Object} parentMeta - The parent's resolved block metadata.
 * @param {string} parentName - Parent block name for error messages.
 * @param {string} outletName - The outlet name for error messages.
 * @param {Object} context - Error context for raiseBlockError.
 * @returns {boolean} True if every child is allowed (or nothing to check).
 */
function validateAllowedChildBlocks(
  entry,
  parentMeta,
  parentName,
  outletName,
  context
) {
  const allowed = parentMeta.childBlocks;
  if (!allowed) {
    return true;
  }
  for (const child of entry.children ?? []) {
    const name = childBlockName(child.block);
    if (name && !allowed.includes(name)) {
      raiseBlockError(
        `Block component ${parentName} in layout ${outletName} only accepts ` +
          `${allowed.join(", ")} as direct children, but got "${name}".`,
        {
          ...context,
          details: {
            code: ERROR_CODES.INVALID_CHILDREN,
            expected: { childBlocks: allowed },
          },
        }
      );
      return false;
    }
  }
  return true;
}

/**
 * Validates block constraints and custom validation functions.
 * Applies arg defaults before validation.
 *
 * In strict mode (no `collect`) a violation throws fail-fast via
 * `raiseBlockError` — the historical contract that keeps `api.renderBlocks`
 * callers' consoles clean. When a `collect` array is supplied, violations are
 * appended to it (as `{ message, path, details }`) instead of thrown, so the
 * caller can accumulate them alongside arg failures and surface every problem
 * at once rather than one-then-the-next across republishes.
 *
 * @param {Object} metadata - Block metadata with constraints/validate.
 * @param {Object} resolvedBlock - The resolved block class.
 * @param {Object} entry - The block entry.
 * @param {string} blockName - The block name for error messages.
 * @param {Object|null} context - Error context for raiseBlockError (strict mode).
 * @param {Object} [options]
 * @param {Array<{message: string, path: string, details?: Object}>} [options.collect] -
 *   When provided, violations are appended here instead of thrown.
 */
function validateBlockConstraints(
  metadata,
  resolvedBlock,
  entry,
  blockName,
  context,
  { collect = null } = {}
) {
  if (!metadata?.constraints && !metadata?.validate) {
    return;
  }

  const argsWithDefaults = applyArgDefaults(resolvedBlock, entry.args || {});

  // Append to the collector (accumulate mode) or throw with full context
  // (fail-fast mode), depending on whether a collector was supplied.
  const report = (errorPath, message, details) => {
    if (collect) {
      collect.push({ message, path: errorPath, details });
    } else {
      raiseBlockError(
        `Invalid block "${blockName}" at ${context.path} for outlet "${context.outletName}": ${message}`,
        { ...context, errorPath, details }
      );
    }
  };

  // Validate declarative constraints
  if (metadata.constraints) {
    const constraintError = validateConstraints(
      metadata.constraints,
      argsWithDefaults,
      blockName
    );
    if (constraintError) {
      report("constraints", constraintError.message, constraintError.details);
    }
  }

  // Run custom validation function
  if (metadata.validate) {
    const customErrors = runCustomValidation(
      metadata.validate,
      argsWithDefaults
    );
    if (customErrors?.length > 0) {
      const errorMessage =
        customErrors.length === 1
          ? customErrors[0]
          : customErrors.map((e) => `  - ${e}`).join("\n");
      report("validate", errorMessage, {
        code: ERROR_CODES.CONSTRAINT_VIOLATION,
        expected: { custom: true },
      });
    }
  }
}

/**
 * Collects the soft-failure details for a single entry's args and
 * constraints, gathered into the same `__failureDetails` array shape the
 * full permissive layout pass stamps onto an entry — but returned instead
 * of thrown, and without needing the surrounding layout/outlet context.
 *
 * Reuses the exact validators the full pass runs per entry
 * (`validateBlockArgs` in collect mode, plus `validateConstraints` /
 * `runCustomValidation` over args-with-defaults), so there is one source
 * of validation truth.
 *
 * Scope is deliberately limited to the checks an in-session arg edit can
 * change: argument-level validation, declarative `constraints`, and a
 * custom `validate` function. Structural concerns (children, containerArgs,
 * ids, conditions) are unaffected by an arg edit and stay owned by the
 * next full republish.
 *
 * @param {Object} entry - The block entry whose current `args` to check.
 * @param {(import("discourse/lib/blocks/-internals/registry/block").BlockClass|string)} blockClass -
 *   The `@block`-decorated class, OR a string block-name ref (as layout
 *   entries carry — `entry.block` is usually the registered name). A string
 *   is resolved to its class via the registry; a ref that resolves to no
 *   registered metadata yields `[]` (nothing to validate against).
 * @param {Object} [options]
 * @param {Object} [options.owner] - Ember owner for registry lookups (only
 *   used by arg validation for `model:*` `instanceOf` checks).
 * @returns {Array<Object>} The structured failure details (`{ code, field?,
 *   expected? }`), or an empty array when the entry's args and constraints
 *   all pass.
 */
export function collectEntryFailures(entry, blockClass, { owner } = {}) {
  // `entry.block` is usually a string name, not the class. Resolve it the
  // same way the render + publish paths do so string-referenced blocks get
  // validated too — otherwise `getBlockMetadata` (keyed by class) misses and
  // every edit looks valid, silently dropping the block's real failures.
  const resolved = tryResolveBlock(blockClass);
  // A non-class result means the ref is unregistered, an optional-missing
  // marker, or a factory still resolving — nothing to validate against.
  if (typeof resolved !== "function") {
    return [];
  }
  const metadata = getBlockMetadata(resolved);
  if (!metadata) {
    return [];
  }

  // Accumulate arg failures (required / type / pattern / enum / …) then
  // constraint + custom-validate failures into one collector — the same
  // sequence the full permissive pass runs per entry (`validateEntry`), so
  // the edit-time and republish-time stamps match exactly.
  const collector = [];
  try {
    validateBlockArgs(entry, resolved, { owner, collect: collector });
  } catch (err) {
    // `validateBlockArgs` still throws for the "args provided but no schema"
    // case, which collect mode doesn't cover. Surface it as a single detail
    // rather than letting it break the edit.
    if (err instanceof BlockError) {
      collector.push({
        message: err.message,
        path: "",
        details: err.details ?? { code: ERROR_CODES.INVALID_BLOCK },
      });
    } else {
      throw err;
    }
  }

  validateBlockConstraints(
    metadata,
    resolved,
    entry,
    metadata.blockName,
    null,
    {
      collect: collector,
    }
  );

  return collector.map((failure) => failure.details).filter(Boolean);
}

/**
 * Validates a child block's containerArgs against the parent container's childArgs schema.
 * Reuses the shared validateArgsAgainstSchema function for core validation logic.
 *
 * @param {Object} childEntry - The child block entry.
 * @param {Object} parentChildArgsSchema - The parent's childArgs schema.
 * @param {string} parentName - Parent block name for error messages.
 * @param {Object} context - Error context.
 */
function validateContainerArgs(
  childEntry,
  parentChildArgsSchema,
  parentName,
  context
) {
  const providedArgs = childEntry.containerArgs || {};

  try {
    validateArgsAgainstSchema(
      providedArgs,
      parentChildArgsSchema,
      "containerArgs"
    );
  } catch (error) {
    // Enhance error message with parent context
    raiseBlockError(
      `Child block at ${context.path} ${error.message} (required by parent "${parentName}").`,
      {
        ...context,
        errorPath: buildErrorPath(context.path, error.path),
      }
    );
  }
}

/**
 * Validates uniqueness constraints for containerArgs across all sibling children.
 *
 * @param {Array<Object>} childEntries - Array of child block entries.
 * @param {Object} childArgsSchema - The parent's childArgs schema.
 * @param {string} parentName - Parent block name for error messages.
 * @param {string} parentPath - Path to parent for error context.
 * @param {Object} context - Error context.
 */
function validateContainerArgsUniqueness(
  childEntries,
  childArgsSchema,
  parentName,
  parentPath,
  context
) {
  // Find args with unique: true
  const uniqueArgs = Object.entries(childArgsSchema)
    .filter(([, schema]) => schema.unique)
    .map(([name]) => name);

  for (const argName of uniqueArgs) {
    const seenValues = new Map(); // value -> index of first occurrence

    for (let i = 0; i < childEntries.length; i++) {
      const childEntry = childEntries[i];
      const value = childEntry.containerArgs?.[argName];

      // Skip undefined values (uniqueness only applies to provided values)
      if (value === undefined) {
        continue;
      }

      if (seenValues.has(value)) {
        const firstIndex = seenValues.get(value);
        raiseBlockError(
          `Duplicate value "${value}" for containerArgs.${argName} in children of "${parentName}". ` +
            `Found at children[${firstIndex}] and children[${i}]. ` +
            `The "${argName}" arg must be unique among siblings.`,
          {
            ...context,
            path: `${parentPath}.children[${i}]`,
            errorPath: `${parentPath}.children[${i}].containerArgs.${argName}`,
          }
        );
      }

      seenValues.set(value, i);
    }
  }
}

/**
 * Validates that a block entry's `id` matches the required pattern.
 * IDs must start with a lowercase letter and contain only lowercase letters,
 * numbers, and hyphens (same format as block names).
 *
 * @param {Object} entry - The block entry.
 * @throws {BlockError} If the id format is invalid.
 */
export function validateEntryIdFormat(entry) {
  if (!entry.id) {
    return;
  }

  if (!VALID_BLOCK_ID_PATTERN.test(entry.id)) {
    // The structured `details` lets error consumers render a short,
    // author-facing message instead of the raw developer string.
    throw new BlockError(
      `"id" value "${entry.id}" is invalid. ` +
        `IDs must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens.`,
      {
        path: "id",
        details: {
          code: ERROR_CODES.INVALID_ENTRY_ID,
          value: entry.id,
        },
      }
    );
  }
}

/**
 * Validates that containerArgs is not provided when parent has no childArgs.
 * Follows the pattern: error in dev/test, warn in production.
 *
 * @param {Object} entry - The block entry.
 * @param {Object} parentChildArgsSchema - The parent's childArgs schema (null if none).
 * @param {Object} context - Error context.
 */
function validateOrphanContainerArgs(entry, parentChildArgsSchema, context) {
  if (entry.containerArgs && !parentChildArgsSchema) {
    const message =
      `Block at ${context.path} has "containerArgs" but parent container does not declare "childArgs". ` +
      `Remove the containerArgs or add a childArgs schema to the parent.`;

    if (DEBUG) {
      raiseBlockError(message, context);
    } else {
      // eslint-disable-next-line no-console
      console.warn(`[Blocks] ${message}`);
    }
  }
}

/**
 * Validates block conditions and raises errors with proper context.
 *
 * @param {Object} blocksService - The blocks service with validate method.
 * @param {Object} entry - The block entry containing conditions.
 * @param {string} outletName - The outlet name for error messages.
 * @param {string} blockName - The block name for error messages.
 * @param {string} path - The path in the layout tree for error messages.
 * @param {Error | null} [callSiteError] - Error object capturing where renderBlocks() was called.
 * @param {Array<Object>} [rootLayout] - The root blocks array for error context display.
 */
function validateBlockConditions(
  blocksService,
  entry,
  outletName,
  blockName,
  path,
  callSiteError = null,
  rootLayout = null
) {
  if (!entry.conditions || !blocksService) {
    return;
  }

  try {
    blocksService.validate(entry.conditions);
  } catch (error) {
    // Build context for error message - include rootLayout for tree display
    const context = {
      ...createValidationContext({
        outletName,
        blockName,
        path,
        entry,
        callSiteError,
        rootLayout,
      }),
      conditions: entry.conditions,
    };

    // If error has a path property, build the full errorPath and conditionsPath
    // error.path is relative to conditions (e.g., "params.categoryId")
    if (error.path) {
      context.errorPath = buildErrorPath(
        path,
        buildErrorPath("conditions", error.path)
      );
      // conditionsPath is relative to the conditions object (for formatter)
      context.conditionsPath = error.path;
    }

    raiseBlockError(
      `Invalid conditions for block "${blockName}" in outlet "${outletName}": ${error.message}`,
      context
    );
  }
}

/**
 * Resolves a block reference (string or class) to a BlockClass for validation.
 *
 * This function handles the dual-mode resolution strategy:
 *
 * - **Development/Test mode**: Eagerly resolves all block references including
 *   factory functions. This ensures errors surface early at boot time with clear
 *   stack traces.
 *
 * - **Production mode**: Only resolves if the block is already resolved (not a
 *   pending factory). Factories are left unresolved, with validation deferred to
 *   render time. This enables true lazy loading.
 *
 * **Optional blocks**: Block references ending with `?` are treated as optional.
 * If an optional block is not registered, an object with `OPTIONAL_MISSING`
 * is returned instead of throwing an error. The calling code should check for this
 * marker and skip validation/rendering for the block.
 *
 * @param {string | Object} blockRef - Block name string (possibly with `?` suffix) or BlockClass.
 * @param {string} outletName - Outlet name for error messages.
 * @param {Object} [context] - Context for error messages.
 * @param {string} [context.path] - Path to this entry in the block tree.
 * @param {Object} [context.entry] - The block entry object.
 * @param {Error} [context.callSiteError] - Error capturing call site location.
 * @param {Array} [context.rootLayout] - Root layout array for error display.
 * @returns {Promise<Object | string | { [OPTIONAL_MISSING]: true, name: string }>}
 *   Resolved BlockClass, string name if deferred, or optional missing marker object.
 * @throws {Error} If required block is not registered.
 */
export async function resolveBlockForValidation(
  blockRef,
  outletName,
  context = {}
) {
  // Class reference - return as-is (classes always exist)
  if (typeof blockRef !== "string") {
    return blockRef;
  }

  // Parse optional suffix from block reference
  const { name, optional } = parseBlockReference(blockRef);

  // String reference - check registration
  if (!hasBlock(name)) {
    if (optional) {
      // Optional block not registered - return marker to skip validation
      return { [OPTIONAL_MISSING]: true, name };
    }
    raiseBlockError(
      `Block "${name}" at ${context.path || "unknown"} for outlet "${outletName}" is not registered. ` +
        `Use api.registerBlock() in a pre-initializer before any renderBlocks() configuration.`,
      {
        ...createValidationContext({
          outletName,
          blockName: name,
          path: context.path,
          entry: context.entry,
          callSiteError: context.callSiteError,
          rootLayout: context.rootLayout,
        }),
        details: {
          code: ERROR_CODES.UNREGISTERED_BLOCK,
          value: name,
        },
      }
    );
    return null;
  }

  if (DEBUG) {
    // In dev/test, eagerly resolve to catch factory errors early
    return await resolveBlock(name);
  }

  // In production, only resolve if already resolved (avoid triggering lazy load)
  if (isBlockResolved(name)) {
    return await resolveBlock(name);
  }

  // Return the string name - full validation deferred to render time
  return name;
}

/**
 * Valid top-level keys in block entry objects.
 * Any key not in this list will trigger a validation error, helping catch
 * common typos like `condition` instead of `conditions`.
 */
export const VALID_ENTRY_KEYS = Object.freeze([
  "block", // Block class or name (required)
  "conditions", // Conditions for rendering
  "args", // Arguments to pass to the block
  "containerArgs", // Arguments required by parent container's childArgs schema
  "classNames", // CSS classes to add to wrapper
  "children", // Nested block entries
  "id", // Unique identifier for targeting and BEM styling
  "overrides", // Per-part overrides for a composite block (one that declares
  // `parts`): a flat map keyed by dot-delimited part-id paths, each value the
  // part's own args. Read by the composite renderer; ignored on non-composites.
]);

/**
 * Declarative type validation rules for block entry fields.
 * Each rule specifies how to validate a field's type and generate error messages.
 *
 * @type {Object<string, {
 *   validate: (value: any) => boolean,
 *   expected: string,
 *   actual?: (value: any) => string
 * }>}
 */
const ENTRY_TYPE_RULES = {
  args: {
    validate: (v) => typeof v === "object" && !Array.isArray(v),
    expected: "an object",
    actual: (v) => (Array.isArray(v) ? "array" : typeof v),
  },
  containerArgs: {
    validate: (v) => typeof v === "object" && !Array.isArray(v),
    expected: "an object",
    actual: (v) => (Array.isArray(v) ? "array" : typeof v),
  },
  overrides: {
    validate: (v) => typeof v === "object" && !Array.isArray(v),
    expected: "an object",
    actual: (v) => (Array.isArray(v) ? "array" : typeof v),
  },
  children: {
    validate: (v) => Array.isArray(v),
    expected: "an array",
    actual: (v) => typeof v,
  },
  classNames: {
    validate: (v) =>
      typeof v === "string" ||
      (Array.isArray(v) && v.every((item) => typeof item === "string")),
    expected: "a string or array of strings",
    actual: (v) =>
      Array.isArray(v) ? "array with non-string items" : typeof v,
  },
  conditions: {
    validate: (v) => typeof v === "object",
    expected: "an object or array",
    actual: (v) => typeof v,
  },
  id: {
    validate: (v) => typeof v === "string",
    expected: "a string",
    actual: (v) => typeof v,
  },
};

/**
 * Validates that a block entry only uses known keys.
 * Uses fuzzy matching to suggest corrections for typos like "condition",
 * "codition", or "conditons" instead of "conditions".
 *
 * Internal keys (starting with `__`) are skipped as they are added by the
 * system during preprocessing (e.g., `__visible`, `__failureReason`).
 *
 * @param {Object} entry - The block entry object.
 * @throws {BlockError} If unknown keys are found.
 */
export function validateEntryKeys(entry) {
  const unknownKeys = Object.keys(entry).filter(
    (key) => !key.startsWith("__") && !VALID_ENTRY_KEYS.includes(key)
  );

  if (unknownKeys.length > 0) {
    // Build helpful suggestions using fuzzy matching from shared lib
    const suggestions = unknownKeys.map((key) =>
      formatWithSuggestion(key, VALID_ENTRY_KEYS)
    );

    const keyWord = unknownKeys.length > 1 ? "keys" : "key";
    // Throw BlockError directly - wrapValidationError will add context.
    // The structured `details` lets error consumers render a short,
    // author-facing message instead of the raw developer string.
    throw new BlockError(
      `Unknown entry ${keyWord}: ${suggestions.join(", ")}. ` +
        `Valid keys are: ${VALID_ENTRY_KEYS.join(", ")}.`,
      {
        path: unknownKeys[0],
        details: {
          code: ERROR_CODES.UNKNOWN_ENTRY_KEY,
          expected: { keys: unknownKeys, validKeys: [...VALID_ENTRY_KEYS] },
        },
      }
    );
  }
}

/**
 * Validates the types of optional entry fields.
 * Iterates over ENTRY_TYPE_RULES to check each field's type.
 *
 * @param {Object} entry - The block entry object.
 * @throws {BlockError} If any field has an invalid type.
 */
export function validateEntryTypes(entry) {
  for (const [field, rule] of Object.entries(ENTRY_TYPE_RULES)) {
    const value = entry[field];
    if (value != null && !rule.validate(value)) {
      const actualType = rule.actual?.(value) ?? typeof value;
      // Throw BlockError directly - wrapValidationError will add context.
      // The structured `details` lets error consumers render a short,
      // author-facing message instead of the raw developer string.
      throw new BlockError(
        `"${field}" must be ${rule.expected}, got ${actualType}.`,
        {
          path: field,
          details: {
            code: ERROR_CODES.INVALID_ENTRY_TYPE,
            expected: { key: field, type: rule.expected, got: actualType },
          },
        }
      );
    }
  }
}

/**
 * Validation context passed through layout validation recursion.
 * Created at the root level and shared across all entries to enable
 * cross-cutting validation (e.g., ID uniqueness across the entire tree).
 *
 * @typedef {Object} LayoutValidationContext
 * @property {Map<string, {path: string}>} seenIds - Map of entry IDs to their paths for uniqueness validation.
 * @property {boolean} [permissive] - When true, per-entry failures are caught
 *   and recorded as soft failures instead of aborting the whole layout.
 * @property {boolean} [collect] - When true, arg validation accumulates every
 *   failure into a single synthetic error (used by permissive consumers).
 * @property {Array<{message: string, path: string, error: Error, details: any}>} [warnings] -
 *   Soft-failure log populated in permissive mode.
 */

/**
 * Recursively validates an outlet layout (array of block entries).
 * Validates each block entry and traverses nested children.
 *
 * This function is async to support lazy-loaded blocks:
 * - In dev/test: Eagerly resolves all factories for early error detection.
 * - In production: Defers factory resolution to render time.
 *
 * @param {Array<Object>} layout - The outlet layout (array of block entries) to validate.
 * @param {string} outletName - The outlet these blocks belong to.
 * @param {import("discourse/services/blocks").default} blocksService - Service for validating conditions.
 * @param {string} [parentPath=""] - JSON-path style parent location for error context.
 * @param {Error | null} [callSiteError] - Where renderBlocks() was called from.
 * @param {Array<Object>} [rootLayout] - The root layout array for error context display.
 * @param {Object|null} [parentChildArgsSchema=null] - The parent container's childArgs schema, if any.
 * @param {string|null} [parentBlockName=null] - The parent container's block name for error messages.
 * @param {number} [depth=0] - Current nesting depth for recursion limit checking.
 * @param {LayoutValidationContext} [context] - Validation context for cross-cutting concerns like ID uniqueness.
 * @returns {Promise<void>} Resolves when validation completes.
 * @throws {Error} If any block entry is invalid or nesting depth exceeds MAX_LAYOUT_DEPTH.
 */
export async function validateLayout(
  layout,
  outletName,
  blocksService,
  parentPath = "",
  callSiteError = null,
  rootLayout = null,
  parentChildArgsSchema = null,
  parentBlockName = null,
  depth = 0,
  context = { seenIds: new Map() }
) {
  // On first call, capture the root layout for error display
  const effectiveRootLayout = rootLayout ?? layout;

  // Check recursion depth limit to prevent stack overflow from deeply nested layouts
  if (depth >= MAX_LAYOUT_DEPTH) {
    raiseBlockError(
      `Layout exceeds maximum nesting depth of ${MAX_LAYOUT_DEPTH}. ` +
        `Deeply nested layouts may indicate a configuration issue.`,
      createValidationContext({
        outletName,
        path: parentPath,
        callSiteError,
        rootLayout: effectiveRootLayout,
      })
    );
  }

  // Validate containerArgs uniqueness across siblings if parent has childArgs with unique constraints
  if (parentChildArgsSchema) {
    validateContainerArgsUniqueness(
      layout,
      parentChildArgsSchema,
      parentBlockName,
      parentPath.replace(/\.children$/, ""),
      createValidationContext({
        outletName,
        path: parentPath,
        callSiteError,
        rootLayout: effectiveRootLayout,
      })
    );
  }

  // Per-entry validation. In strict mode, the first entry's failure
  // bubbles up and rejects the whole layout (the historical contract).
  // In permissive mode, each entry's validation is wrapped in try/catch
  // so a failure marks JUST that entry (`__failureType` /
  // `__failureReason` set on the entry itself, message pushed to
  // `context.warnings`) and the next entry's validation continues. The
  // recursion to children inherits `context`, so granularity is per-
  // entry at every nesting level — a typo three levels deep marks that
  // descendant without invalidating its ancestors.
  const validationPromises = layout.map(async (entry, index) => {
    const currentPath = `${parentPath}[${index}]`;
    try {
      await validateOneEntry({
        entry,
        currentPath,
        outletName,
        blocksService,
        callSiteError,
        effectiveRootLayout,
        parentChildArgsSchema,
        parentBlockName,
        depth,
        context,
      });
    } catch (err) {
      if (context.permissive && err?.name === "BlockError") {
        markEntrySoftFailure(entry, err);
        context.warnings?.push({
          message: err.message,
          path: currentPath,
          error: err,
          details: entry.__failureDetails,
        });
        return;
      }
      throw err;
    }
  });

  await Promise.all(validationPromises);
}

/**
 * Marks a layout entry as softly invalid. Adopts the same `__failureType`
 * / `__failureReason` shape that `BlockOutletRootContainer#preprocessEntries`
 * already uses for condition-failed and no-visible-children, so the
 * existing ghost-rendering path picks the entry up without further
 * plumbing.
 *
 * @param {Object} entry
 * @param {Error & { details?: any }} err
 */
function markEntrySoftFailure(entry, err) {
  entry.__visible = false;
  entry.__failureType = "structural-invalid";
  entry.__failureReason = err.message;
  // Always an array for consumer consistency. In permissive/collect mode,
  // `err.details` is already the accumulated list; in strict mode it's a
  // single detail object which we wrap. `null` becomes an empty array so
  // consumers never have to branch on shape.
  entry.__failureDetails = Array.isArray(err.details)
    ? err.details
    : err.details
      ? [err.details]
      : [];
}

/**
 * The per-entry validation body, extracted so the outer per-entry
 * try/catch in `validateLayout` is the single boundary between "this
 * entry blew up" and "everything else keeps going". Pure orchestration
 * — same calls validateLayout used to make inline.
 */
async function validateOneEntry({
  entry,
  currentPath,
  outletName,
  blocksService,
  callSiteError,
  effectiveRootLayout,
  parentChildArgsSchema,
  parentBlockName,
  depth,
  context,
}) {
  // Check ID uniqueness across the entire layout using shared context
  if (entry.id) {
    if (context.seenIds.has(entry.id)) {
      const first = context.seenIds.get(entry.id);
      raiseBlockError(
        `Duplicate block id "${entry.id}" in outlet "${outletName}". ` +
          `Found at ${first.path} and ${currentPath}. Block IDs must be unique per layout.`,
        {
          ...createValidationContext({
            outletName,
            path: currentPath,
            entry,
            callSiteError,
            rootLayout: effectiveRootLayout,
          }),
          errorPath: `${currentPath}.id`,
          details: {
            code: ERROR_CODES.DUPLICATE_ID,
            field: "id",
            value: entry.id,
            expected: { firstPath: first.path },
          },
        }
      );
    }
    context.seenIds.set(entry.id, { path: currentPath });
  }

  // Validate the block entry itself (whether it has children or not)
  // Returns the block's childArgsSchema if it's a container with childArgs.
  // Pass the LayoutValidationContext through so validateEntry can opt in
  // to per-entry arg accumulation in permissive/collect mode.
  const childArgsSchema = await validateEntry(
    entry,
    outletName,
    blocksService,
    currentPath,
    callSiteError,
    effectiveRootLayout,
    parentChildArgsSchema,
    parentBlockName,
    context
  );

  // Recursively validate nested children
  if (entry.children) {
    // Get the block name for error messages when passing childArgs to children
    let blockName = null;
    if (childArgsSchema) {
      // We need the block name for error messages - resolve it
      const resolved = await resolveBlockForValidation(
        entry.block,
        outletName,
        createValidationContext({
          outletName,
          path: currentPath,
          entry,
          callSiteError,
          rootLayout: effectiveRootLayout,
        })
      );
      if (
        resolved &&
        typeof resolved !== "string" &&
        !resolved[OPTIONAL_MISSING]
      ) {
        blockName = getBlockMetadata(resolved)?.blockName;
      }
    }

    await validateLayout(
      entry.children,
      outletName,
      blocksService,
      `${currentPath}.children`,
      callSiteError,
      effectiveRootLayout,
      childArgsSchema,
      blockName,
      depth + 1,
      context
    );
  }
}

/**
 * Validates a single block entry object.
 *
 * Performs comprehensive validation including:
 * - Outlet name is a valid registered outlet (core or custom)
 * - Block reference is valid (string name or @block-decorated class)
 * - Block is registered in the registry
 * - Container/children relationship is valid
 * - No reserved arg names are used
 * - containerArgs match parent's childArgs schema (if applicable)
 * - Conditions are valid (if blocksService is provided)
 *
 * This function is async to support lazy-loaded blocks. In production mode,
 * if a block reference is a string pointing to an unresolved factory, full
 * validation is deferred to render time.
 *
 * @param {Object} entry - The block entry object.
 * @param {typeof import("@glimmer/component").default | string} entry.block - Block class or name string.
 * @param {Object} [entry.args] - Args to pass to the block.
 * @param {Object} [entry.containerArgs] - Args required by parent container's childArgs schema.
 * @param {Array<Object>} [entry.children] - Nested block entries.
 * @param {Array<Object>|Object} [entry.conditions] - Conditions for rendering.
 * @param {string} outletName - The outlet this block belongs to.
 * @param {import("discourse/services/blocks").default} blocksService - Service for validating conditions.
 * @param {string} [path] - JSON-path style location in layout (e.g., "[3].children[0]").
 * @param {Error | null} [callSiteError] - Where renderBlocks() was called from.
 * @param {Array<Object>} [rootLayout] - The root layout array for error context display.
 * @param {Object|null} [parentChildArgsSchema=null] - The parent container's childArgs schema, if any.
 * @param {string|null} [parentBlockName=null] - The parent container's block name for error messages.
 * @returns {Promise<Object|null>} The block's childArgsSchema if it's a container with childArgs, otherwise null.
 * @throws {Error} If validation fails.
 */
export async function validateEntry(
  entry,
  outletName,
  blocksService,
  path,
  callSiteError = null,
  rootLayout = null,
  parentChildArgsSchema = null,
  parentBlockName = null,
  context = null
) {
  // Create context without blockName for early validation errors
  const earlyContext = createValidationContext({
    outletName,
    path,
    entry,
    callSiteError,
    rootLayout,
  });

  if (!isValidOutlet(outletName)) {
    const allOutlets = getAllOutlets();
    const suggestion = formatWithSuggestion(outletName, allOutlets);
    raiseBlockError(
      `Unknown block outlet: ${suggestion}. ` +
        `Register custom outlets with api.registerBlockOutlet() in a pre-initializer. ` +
        `Available outlets: ${allOutlets.join(", ")}`,
      earlyContext
    );
    return null;
  }

  // Validate entry structure (keys, types, and id format) with error tracing
  wrapValidationError(
    () => {
      validateEntryKeys(entry);
      validateEntryTypes(entry);
      validateEntryIdFormat(entry);
    },
    `Invalid block entry at ${path} for outlet "${outletName}"`,
    earlyContext
  );

  if (!entry.block) {
    raiseBlockError(
      `Block entry at ${path} for outlet "${outletName}" is missing required "block" property.`,
      {
        ...earlyContext,
        details: {
          code: ERROR_CODES.INVALID_BLOCK,
          field: "block",
        },
      }
    );
    return null;
  }

  // Resolve block reference (string name or class)
  // In dev: eagerly resolves factories
  // In prod: returns string if factory is unresolved (defers to render time)
  const resolvedBlock = await resolveBlockForValidation(
    entry.block,
    outletName,
    earlyContext
  );

  // If resolution returned null (error was raised), exit early
  if (resolvedBlock === null) {
    return null;
  }

  // Optional block not registered - skip validation entirely
  if (resolvedBlock?.[OPTIONAL_MISSING]) {
    return null;
  }

  // In production with unresolved factory, defer full validation to render time
  // We've already verified the block name is registered in resolveBlockForValidation
  if (typeof resolvedBlock === "string") {
    const blockName = resolvedBlock;

    // Validate conditions since they don't depend on the block class
    validateBlockConditions(
      blocksService,
      entry,
      outletName,
      blockName,
      path,
      callSiteError,
      rootLayout
    );

    // Skip class-specific validation (will happen at render time)
    return null;
  }

  // Full validation with resolved class
  const blockMeta = getBlockMetadata(resolvedBlock);
  if (!blockMeta) {
    raiseBlockError(
      `Block "${resolvedBlock?.name || "unknown"}" at ${path} for outlet "${outletName}" is not a valid @block-decorated component.`,
      {
        ...earlyContext,
        details: { code: ERROR_CODES.INVALID_BLOCK },
      }
    );
    return null;
  }

  const blockName = blockMeta.blockName;

  // Build base context for all validation errors in this block
  const baseContext = createValidationContext({
    outletName,
    blockName,
    path,
    entry,
    callSiteError,
    rootLayout,
  });

  // Validate outlet permission (allowedOutlets/deniedOutlets)
  if (
    !validateOutletPermission(blockMeta, outletName, blockName, baseContext)
  ) {
    return null;
  }

  // Validate container/children relationship
  const isContainer = blockMeta.isContainer;
  const hasParts = blockMeta.parts != null;
  if (
    !validateContainerChildren(
      entry,
      isContainer,
      hasParts,
      blockName,
      outletName,
      baseContext
    )
  ) {
    return null;
  }

  // Validate each direct child against the parent's `childBlocks` allow-list.
  if (
    !validateAllowedChildBlocks(
      entry,
      blockMeta,
      blockName,
      outletName,
      baseContext
    )
  ) {
    return null;
  }

  // Validate block args against schema.
  //
  // In strict mode `validateBlockArgs` throws on the first failure (the
  // historical fail-fast contract — keeps `api.renderBlocks` callers'
  // consoles clean). In permissive/collect mode we hand it a collector
  // so it records every bad arg into the array, then raise one synthetic
  // error whose `details` is the full list. The outer per-entry try/catch
  // in `validateLayout` catches that synthetic error and routes it through
  // `markEntrySoftFailure`, stamping the array on the entry — that's what
  // powers per-field inline errors instead of whack-a-mole "fix one, see
  // the next".
  const errorPrefix = `Invalid block "${blockName}" at ${path} for outlet "${outletName}"`;
  const owner = blocksService ? getOwner(blocksService) : null;
  const collector = context?.collect ? [] : null;

  // Validate args first. In strict mode this throws on the first bad arg
  // (fail-fast); in collect mode it records every bad arg into `collector`
  // without throwing.
  wrapValidationError(
    () =>
      validateBlockArgs(entry, resolvedBlock, { owner, collect: collector }),
    errorPrefix,
    baseContext
  );

  // Then constraints + custom validation (after defaults). In strict mode
  // these throw fail-fast; in collect mode they append to the SAME collector
  // so an entry with both a bad arg and an unmet constraint surfaces both at
  // once — without this, fixing the arg only reveals the constraint on the
  // next republish (whack-a-mole).
  validateBlockConstraints(
    blockMeta,
    resolvedBlock,
    entry,
    blockName,
    baseContext,
    {
      collect: collector,
    }
  );

  if (collector && collector.length > 0) {
    const combinedMessage = collector.map((e) => e.message).join(" ");
    raiseBlockError(`${errorPrefix}: ${combinedMessage}`, {
      ...baseContext,
      errorPath: buildErrorPath(baseContext.path, collector[0].path),
      details: collector.map((e) => e.details).filter(Boolean),
    });
  }

  // Validate conditions if service is available
  validateBlockConditions(
    blocksService,
    entry,
    outletName,
    blockName,
    path,
    callSiteError,
    rootLayout
  );

  // Validate containerArgs against parent's childArgs schema
  if (parentChildArgsSchema) {
    validateContainerArgs(
      entry,
      parentChildArgsSchema,
      parentBlockName,
      baseContext
    );
  }

  // Validate orphan containerArgs (containerArgs without parent's childArgs)
  validateOrphanContainerArgs(entry, parentChildArgsSchema, baseContext);

  // Return the block's childArgsSchema for validating its children
  return isContainer ? blockMeta.childArgs : null;
}
