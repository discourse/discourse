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
 */
import { DEBUG } from "@glimmer/env";
import { getOwner } from "@ember/owner";
import type {
  BlockMetadata,
  ChildArgSchema,
  LayoutEntry,
} from "discourse/blocks/types";
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
} from "discourse/lib/blocks/-internals/registry/block";
import {
  getAllOutlets,
  isValidOutlet,
} from "discourse/lib/blocks/-internals/registry/outlet";
import type { BlockClass } from "discourse/lib/blocks/-internals/types";
import {
  applyArgDefaults,
  buildErrorPath,
  createValidationContext,
  type ValidationContext,
} from "discourse/lib/blocks/-internals/utils";
import { validateArgsAgainstSchema } from "discourse/lib/blocks/-internals/validation/args";
import { validateBlockArgs } from "discourse/lib/blocks/-internals/validation/block-args";
import {
  runCustomValidation,
  validateConstraints,
} from "discourse/lib/blocks/-internals/validation/constraints";
import { formatWithSuggestion } from "discourse/lib/string-similarity";
import type Blocks from "discourse/services/blocks";

/**
 * Widens a `LayoutEntry` to the generic record shape `ValidationContext`
 * expects for error-message rendering. `LayoutEntry` has no index signature,
 * so it isn't directly assignable to `Record<string, unknown>` even though
 * every field it declares is a valid record entry — hence the two-step cast.
 */
function asContextEntry(
  entry: LayoutEntry | null | undefined
): Record<string, unknown> | null {
  return entry ? (entry as unknown as Record<string, unknown>) : null;
}

/** Same widening as {@link asContextEntry}, for a full layout array. */
function asContextLayout(
  layout: LayoutEntry[] | null | undefined
): Array<Record<string, unknown>> | null {
  return layout ? (layout as unknown as Array<Record<string, unknown>>) : null;
}

/**
 * Wraps a validation function call with BlockError handling.
 * Catches errors with a `path` property and re-raises with full context.
 *
 * @param validationFn - The validation function to call.
 * @param errorPrefix - Prefix for the error message.
 * @param context - Error context including outletName, blockName, path, etc.
 */
function wrapValidationError(
  validationFn: () => void,
  errorPrefix: string,
  context: ValidationContext
): void {
  try {
    validationFn();
  } catch (error: unknown) {
    // Errors raised by the schema/entry validators below are always
    // `BlockError`-shaped (or a plain `Error` with a `path` property attached
    // manually), never an arbitrary throw.
    const err = error as Error & { path?: string };
    // Errors with path property need context enrichment
    if (err.path) {
      raiseBlockError(`${errorPrefix}: ${err.message}`, {
        ...context,
        errorPath: buildErrorPath(context.path, err.path),
      });
    }
    throw error;
  }
}

/**
 * Validates that a block is permitted in the specified outlet.
 * Checks allowedOutlets and deniedOutlets metadata if present.
 *
 * @param metadata - Block metadata with outlet restrictions.
 * @param outletName - The outlet being validated.
 * @param blockName - The block name for error messages.
 * @param context - Error context for raiseBlockError.
 * @returns True if validation passed, false if error was raised.
 */
function validateOutletPermission(
  metadata: BlockMetadata | null | undefined,
  outletName: string,
  blockName: string,
  context: ValidationContext
): boolean {
  if (!metadata?.allowedOutlets && !metadata?.deniedOutlets) {
    return true;
  }

  const permission = isBlockPermittedInOutlet(
    outletName,
    // `BlockMetadata`'s outlet lists are `readonly` (the decorator freezes
    // them); `isBlockPermittedInOutlet` only reads them, so it's safe to
    // widen back to a mutable array here.
    metadata.allowedOutlets as string[] | null,
    metadata.deniedOutlets as string[] | null
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
 * @param entry - The block entry.
 * @param isContainer - Whether the block is a container.
 * @param blockName - The block name for error messages.
 * @param outletName - The outlet name for error messages.
 * @param context - Error context for raiseBlockError.
 * @returns True if validation passed, false if error was raised.
 */
function validateContainerChildren(
  entry: LayoutEntry,
  isContainer: boolean,
  blockName: string,
  outletName: string,
  context: ValidationContext
): boolean {
  const hasChildren = !!entry.children?.length;

  if (hasChildren && !isContainer) {
    raiseBlockError(
      `Block component ${blockName} in layout ${outletName} cannot have children`,
      context
    );
    return false;
  }

  if (isContainer && !hasChildren) {
    raiseBlockError(
      `Block component ${blockName} in layout ${outletName} must have children`,
      context
    );
    return false;
  }
  return true;
}

/**
 * Validates block constraints and custom validation functions.
 * Applies arg defaults before validation.
 *
 * @param metadata - Block metadata with constraints/validate.
 * @param resolvedBlock - The resolved block class.
 * @param entry - The block entry.
 * @param blockName - The block name for error messages.
 * @param context - Error context for raiseBlockError.
 */
function validateBlockConstraints(
  metadata: BlockMetadata | null | undefined,
  resolvedBlock: BlockClass,
  entry: LayoutEntry,
  blockName: string,
  context: ValidationContext
): void {
  if (!metadata?.constraints && !metadata?.validate) {
    return;
  }

  const argsWithDefaults = applyArgDefaults(resolvedBlock, entry.args || {});

  // Validate declarative constraints
  if (metadata.constraints) {
    const constraintError = validateConstraints(
      metadata.constraints,
      argsWithDefaults,
      blockName
    );
    if (constraintError) {
      raiseBlockError(
        `Invalid block "${blockName}" at ${context.path} for outlet "${context.outletName}": ${constraintError}`,
        { ...context, errorPath: "constraints" }
      );
    }
  }

  // Run custom validation function
  if (metadata.validate) {
    const customErrors = runCustomValidation(
      metadata.validate,
      argsWithDefaults
    );
    if (customErrors && customErrors.length > 0) {
      const errorMessage =
        customErrors.length === 1
          ? customErrors[0]
          : customErrors.map((e) => `  - ${e}`).join("\n");
      raiseBlockError(
        `Invalid block "${blockName}" at ${context.path} for outlet "${context.outletName}": ${errorMessage}`,
        { ...context, errorPath: "validate" }
      );
    }
  }
}

/**
 * Validates a child block's containerArgs against the parent container's childArgs schema.
 * Reuses the shared validateArgsAgainstSchema function for core validation logic.
 *
 * @param childEntry - The child block entry.
 * @param parentChildArgsSchema - The parent's childArgs schema.
 * @param parentName - Parent block name for error messages.
 * @param context - Error context.
 */
function validateContainerArgs(
  childEntry: LayoutEntry,
  parentChildArgsSchema: Record<string, ChildArgSchema>,
  parentName: string | null,
  context: ValidationContext
): void {
  const providedArgs = childEntry.containerArgs || {};

  try {
    validateArgsAgainstSchema(
      providedArgs,
      parentChildArgsSchema,
      "containerArgs"
    );
  } catch (error: unknown) {
    // Enhance error message with parent context
    const err = error as BlockError;
    raiseBlockError(
      `Child block at ${context.path} ${err.message} (required by parent "${parentName}").`,
      {
        ...context,
        errorPath: buildErrorPath(context.path, err.path ?? ""),
      }
    );
  }
}

/**
 * Validates uniqueness constraints for containerArgs across all sibling children.
 *
 * @param childEntries - Array of child block entries.
 * @param childArgsSchema - The parent's childArgs schema.
 * @param parentName - Parent block name for error messages.
 * @param parentPath - Path to parent for error context.
 * @param context - Error context.
 */
function validateContainerArgsUniqueness(
  childEntries: LayoutEntry[],
  childArgsSchema: Record<string, ChildArgSchema>,
  parentName: string | null,
  parentPath: string,
  context: ValidationContext
): void {
  // Find args with unique: true
  const uniqueArgs = Object.entries(childArgsSchema)
    .filter(([, schema]) => schema.unique)
    .map(([name]) => name);

  for (const argName of uniqueArgs) {
    const seenValues = new Map<unknown, number>(); // value -> index of first occurrence

    for (let i = 0; i < childEntries.length; i++) {
      const childEntry = childEntries[i];
      const value = childEntry?.containerArgs?.[argName];

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
 * @param entry - The block entry.
 * @throws BlockError if the id format is invalid.
 */
export function validateEntryIdFormat(entry: LayoutEntry): void {
  if (!entry.id) {
    return;
  }

  if (!VALID_BLOCK_ID_PATTERN.test(entry.id)) {
    throw new BlockError(
      `"id" value "${entry.id}" is invalid. ` +
        `IDs must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens.`,
      { path: "id" }
    );
  }
}

/**
 * Validates that containerArgs is not provided when parent has no childArgs.
 * Follows the pattern: error in dev/test, warn in production.
 *
 * @param entry - The block entry.
 * @param parentChildArgsSchema - The parent's childArgs schema (null if none).
 * @param context - Error context.
 */
function validateOrphanContainerArgs(
  entry: LayoutEntry,
  parentChildArgsSchema: Record<string, ChildArgSchema> | null,
  context: ValidationContext
): void {
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
 * @param blocksService - The blocks service with validate method.
 * @param entry - The block entry containing conditions.
 * @param outletName - The outlet name for error messages.
 * @param blockName - The block name for error messages.
 * @param path - The path in the layout tree for error messages.
 * @param callSiteError - Error object capturing where renderBlocks() was called.
 * @param rootLayout - The root blocks array for error context display.
 */
function validateBlockConditions(
  blocksService: Blocks | undefined,
  entry: LayoutEntry,
  outletName: string,
  blockName: string,
  path: string,
  callSiteError: Error | null = null,
  rootLayout: LayoutEntry[] | null = null
): void {
  if (!entry.conditions || !blocksService) {
    return;
  }

  try {
    blocksService.validate(entry.conditions);
  } catch (error: unknown) {
    // Build context for error message - include rootLayout for tree display
    const context: ValidationContext = {
      ...createValidationContext({
        outletName,
        blockName,
        path,
        entry: asContextEntry(entry),
        callSiteError,
        rootLayout: asContextLayout(rootLayout),
      }),
      conditions: entry.conditions,
    };

    // If error has a path property, build the full errorPath and conditionsPath
    // error.path is relative to conditions (e.g., "params.categoryId")
    const err = error as BlockError;
    if (err.path) {
      context.errorPath = buildErrorPath(
        path,
        buildErrorPath("conditions", err.path)
      );
      // conditionsPath is relative to the conditions object (for formatter)
      context.conditionsPath = err.path;
    }

    raiseBlockError(
      `Invalid conditions for block "${blockName}" in outlet "${outletName}": ${err.message}`,
      context
    );
  }
}

/** Context accepted by `resolveBlockForValidation`. */
interface ResolveBlockForValidationContext {
  /** Path to this entry in the block tree. */
  path?: string;
  /** The block entry object. */
  entry?: LayoutEntry | null;
  /** Error capturing call site location. */
  callSiteError?: Error | null;
  /** Root layout array for error display. */
  rootLayout?: LayoutEntry[] | null;
}

/**
 * Marker returned by `resolveBlockForValidation()` for an optional block
 * reference (`name?`) that isn't registered, keyed by the `OPTIONAL_MISSING`
 * symbol (distinct from the `registry/block.ts` `OptionalMissingMarker` shape,
 * which is keyed by the plain `"optionalMissing"` property).
 */
type ResolveOptionalMissingMarker = { [OPTIONAL_MISSING]: true; name: string };

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
 * @param blockRef - Block name string (possibly with `?` suffix) or BlockClass.
 * @param outletName - Outlet name for error messages.
 * @param context - Context for error messages.
 * @returns Resolved BlockClass, string name if deferred, or optional missing marker object.
 * @throws Error if required block is not registered.
 */
export async function resolveBlockForValidation(
  blockRef: string | BlockClass,
  outletName: string,
  context: ResolveBlockForValidationContext = {}
): Promise<
  BlockClass | string | ResolveOptionalMissingMarker | null | undefined
> {
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
      createValidationContext({
        outletName,
        blockName: name,
        path: context.path ?? "",
        entry: asContextEntry(context.entry),
        callSiteError: context.callSiteError,
        rootLayout: asContextLayout(context.rootLayout),
      })
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
export const VALID_ENTRY_KEYS: readonly string[] = Object.freeze([
  "block", // Block class or name (required)
  "conditions", // Conditions for rendering
  "args", // Arguments to pass to the block
  "containerArgs", // Arguments required by parent container's childArgs schema
  "classNames", // CSS classes to add to wrapper
  "children", // Nested block entries
  "id", // Unique identifier for targeting and BEM styling
]);

/**
 * A declarative type-validation rule for one block entry field, used by
 * `ENTRY_TYPE_RULES`.
 */
interface EntryTypeRule {
  /** Checks whether the field's value is valid. */
  validate: (value: unknown) => boolean;
  /** The expected type, for the error message. */
  expected: string;
  /** Describes the actual (invalid) value's type, for the error message.
   *  Falls back to `typeof value` when omitted. */
  actual?: (value: unknown) => string;
}

/**
 * Declarative type validation rules for block entry fields.
 * Each rule specifies how to validate a field's type and generate error messages.
 */
const ENTRY_TYPE_RULES: Record<string, EntryTypeRule> = {
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
 * @param entry - The block entry object.
 * @throws BlockError if unknown keys are found.
 */
export function validateEntryKeys(entry: LayoutEntry): void {
  const unknownKeys = Object.keys(entry).filter(
    (key) => !key.startsWith("__") && !VALID_ENTRY_KEYS.includes(key)
  );

  if (unknownKeys.length > 0) {
    // Build helpful suggestions using fuzzy matching from shared lib
    const suggestions = unknownKeys.map((key) =>
      formatWithSuggestion(key, VALID_ENTRY_KEYS)
    );

    const keyWord = unknownKeys.length > 1 ? "keys" : "key";
    // Throw BlockError directly - wrapValidationError will add context
    throw new BlockError(
      `Unknown entry ${keyWord}: ${suggestions.join(", ")}. ` +
        `Valid keys are: ${VALID_ENTRY_KEYS.join(", ")}.`,
      { path: unknownKeys[0] }
    );
  }
}

/**
 * Validates the types of optional entry fields.
 * Iterates over ENTRY_TYPE_RULES to check each field's type.
 *
 * @param entry - The block entry object.
 * @throws BlockError if any field has an invalid type.
 */
export function validateEntryTypes(entry: LayoutEntry): void {
  // `LayoutEntry` has no index signature, so reading it by a dynamic field
  // name needs the two-step cast (see `asContextEntry` above).
  const entryRecord = entry as unknown as Record<string, unknown>;
  for (const [field, rule] of Object.entries(ENTRY_TYPE_RULES)) {
    const value = entryRecord[field];
    if (value != null && !rule.validate(value)) {
      const actualType = rule.actual?.(value) ?? typeof value;
      // Throw BlockError directly - wrapValidationError will add context
      throw new BlockError(
        `"${field}" must be ${rule.expected}, got ${actualType}.`,
        { path: field }
      );
    }
  }
}

/**
 * Validation context passed through layout validation recursion.
 * Created at the root level and shared across all entries to enable
 * cross-cutting validation (e.g., ID uniqueness across the entire tree).
 */
export interface LayoutValidationContext {
  /** Map of entry IDs to their paths for uniqueness validation. */
  seenIds: Map<string, { path: string }>;
}

/**
 * Recursively validates an outlet layout (array of block entries).
 * Validates each block entry and traverses nested children.
 *
 * This function is async to support lazy-loaded blocks:
 * - In dev/test: Eagerly resolves all factories for early error detection.
 * - In production: Defers factory resolution to render time.
 *
 * @param layout - The outlet layout (array of block entries) to validate.
 * @param outletName - The outlet these blocks belong to.
 * @param blocksService - Service for validating conditions.
 * @param parentPath - JSON-path style parent location for error context.
 * @param callSiteError - Where renderBlocks() was called from.
 * @param rootLayout - The root layout array for error context display.
 * @param parentChildArgsSchema - The parent container's childArgs schema, if any.
 * @param parentBlockName - The parent container's block name for error messages.
 * @param depth - Current nesting depth for recursion limit checking.
 * @param context - Validation context for cross-cutting concerns like ID uniqueness.
 * @throws Error if any block entry is invalid or nesting depth exceeds MAX_LAYOUT_DEPTH.
 */
export async function validateLayout(
  layout: LayoutEntry[],
  outletName: string,
  blocksService: Blocks | undefined,
  parentPath = "",
  callSiteError: Error | null = null,
  rootLayout: LayoutEntry[] | null = null,
  parentChildArgsSchema: Record<string, ChildArgSchema> | null = null,
  parentBlockName: string | null = null,
  depth = 0,
  context: LayoutValidationContext = { seenIds: new Map() }
): Promise<void> {
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
        rootLayout: asContextLayout(effectiveRootLayout),
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
        rootLayout: asContextLayout(effectiveRootLayout),
      })
    );
  }

  // Use Promise.all for parallel validation (faster in dev when resolving factories)
  const validationPromises = layout.map(async (entry, index) => {
    const currentPath = `${parentPath}[${index}]`;

    // Check ID uniqueness across the entire layout using shared context
    if (entry.id) {
      if (context.seenIds.has(entry.id)) {
        const first = context.seenIds.get(entry.id)!;
        raiseBlockError(
          `Duplicate block id "${entry.id}" in outlet "${outletName}". ` +
            `Found at ${first.path} and ${currentPath}. Block IDs must be unique per layout.`,
          {
            ...createValidationContext({
              outletName,
              path: currentPath,
              entry: asContextEntry(entry),
              callSiteError,
              rootLayout: asContextLayout(effectiveRootLayout),
            }),
            errorPath: `${currentPath}.id`,
          }
        );
      }
      context.seenIds.set(entry.id, { path: currentPath });
    }

    // Validate the block entry itself (whether it has children or not)
    // Returns the block's childArgsSchema if it's a container with childArgs
    const childArgsSchema = await validateEntry(
      entry,
      outletName,
      blocksService,
      currentPath,
      callSiteError,
      effectiveRootLayout,
      parentChildArgsSchema,
      parentBlockName
    );

    // Recursively validate nested children
    if (entry.children) {
      // Get the block name for error messages when passing childArgs to children
      let blockName: string | null = null;
      if (childArgsSchema) {
        // We need the block name for error messages - resolve it
        const resolved = await resolveBlockForValidation(
          entry.block,
          outletName,
          {
            path: currentPath,
            entry,
            callSiteError,
            rootLayout: effectiveRootLayout,
          }
        );
        if (
          resolved &&
          typeof resolved !== "string" &&
          !(OPTIONAL_MISSING in resolved)
        ) {
          blockName = getBlockMetadata(resolved)?.blockName ?? null;
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
  });

  await Promise.all(validationPromises);
}

/**
 * Validates a single block entry object.
 *
 * Performs comprehensive validation including:
 * - Outlet name is a valid registered outlet (core or custom)
 * - Block reference is valid (string name or `@block`-decorated class)
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
 * @param entry - The block entry object.
 * @param outletName - The outlet this block belongs to.
 * @param blocksService - Service for validating conditions.
 * @param path - JSON-path style location in layout (e.g., "[3].children[0]").
 * @param callSiteError - Where renderBlocks() was called from.
 * @param rootLayout - The root layout array for error context display.
 * @param parentChildArgsSchema - The parent container's childArgs schema, if any.
 * @param parentBlockName - The parent container's block name for error messages.
 * @returns The block's childArgsSchema if it's a container with childArgs, otherwise null.
 * @throws Error if validation fails.
 */
export async function validateEntry(
  entry: LayoutEntry,
  outletName: string,
  blocksService: Blocks | undefined,
  path: string,
  callSiteError: Error | null = null,
  rootLayout: LayoutEntry[] | null = null,
  parentChildArgsSchema: Record<string, ChildArgSchema> | null = null,
  parentBlockName: string | null = null
): Promise<Record<string, ChildArgSchema> | null> {
  // Create context without blockName for early validation errors
  const earlyContext = createValidationContext({
    outletName,
    path,
    entry: asContextEntry(entry),
    callSiteError,
    rootLayout: asContextLayout(rootLayout),
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
      earlyContext
    );
    return null;
  }

  // Resolve block reference (string name or class)
  // In dev: eagerly resolves factories
  // In prod: returns string if factory is unresolved (defers to render time)
  const resolvedBlock = await resolveBlockForValidation(
    entry.block,
    outletName,
    { path, entry, callSiteError, rootLayout }
  );

  // If resolution returned null (error was raised), exit early
  if (resolvedBlock === null) {
    return null;
  }

  // Optional block not registered - skip validation entirely. `resolvedBlock`
  // can still be `undefined` here (a previously-failed factory resolution,
  // only reachable in DEBUG mode); the `!== undefined` guard falls through
  // exactly like the original's `resolvedBlock?.[OPTIONAL_MISSING]`
  // optional-chaining read, rather than throwing on the `in` operator.
  if (
    resolvedBlock !== undefined &&
    typeof resolvedBlock !== "string" &&
    OPTIONAL_MISSING in resolvedBlock
  ) {
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

  // Full validation with resolved class. `resolvedBlock` can still be
  // `undefined` here for a block whose factory previously failed to resolve
  // (only reachable in DEBUG mode); `getBlockMetadata()`'s underlying WeakMap
  // lookup safely returns `null` for a non-object key at runtime regardless
  // of this cast, so it doesn't change behavior.
  const blockMeta = getBlockMetadata(resolvedBlock as BlockClass);
  if (!blockMeta) {
    raiseBlockError(
      `Block "${(resolvedBlock as { name?: string } | undefined)?.name || "unknown"}" at ${path} for outlet "${outletName}" is not a valid @block-decorated component.`,
      earlyContext
    );
    return null;
  }

  const blockName = blockMeta.blockName;

  // `blockMeta` is only non-null when `resolvedBlock` was an actual
  // registered block class (the `undefined` edge case above always fails
  // that lookup and returns earlier), so `resolvedBlock` is a real
  // `BlockClass` from here on.
  const resolvedBlockClass = resolvedBlock as BlockClass;

  // Build base context for all validation errors in this block
  const baseContext = createValidationContext({
    outletName,
    blockName,
    path,
    entry: asContextEntry(entry),
    callSiteError,
    rootLayout: asContextLayout(rootLayout),
  });

  // Validate outlet permission (allowedOutlets/deniedOutlets)
  if (
    !validateOutletPermission(blockMeta, outletName, blockName, baseContext)
  ) {
    return null;
  }

  // Validate container/children relationship
  const isContainer = blockMeta.isContainer;
  if (
    !validateContainerChildren(
      entry,
      isContainer,
      blockName,
      outletName,
      baseContext
    )
  ) {
    return null;
  }

  // Validate block args against schema
  const errorPrefix = `Invalid block "${blockName}" at ${path} for outlet "${outletName}"`;
  const owner = blocksService ? getOwner(blocksService) : null;
  wrapValidationError(
    () => validateBlockArgs(entry, resolvedBlockClass, { owner }),
    errorPrefix,
    baseContext
  );

  // Validate constraints and custom validation (after applying defaults)
  validateBlockConstraints(
    blockMeta,
    resolvedBlockClass,
    entry,
    blockName,
    baseContext
  );

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
