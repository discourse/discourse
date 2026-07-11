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
  tryResolveBlock,
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
import {
  validateArgsAgainstSchema,
  type ValidateArgValueOptions,
  type ValidationError,
  type ValidationErrorDetails,
} from "discourse/lib/blocks/-internals/validation/args";
import { validateBlockArgs } from "discourse/lib/blocks/-internals/validation/block-args";
import {
  runCustomValidation,
  validateConstraints,
} from "discourse/lib/blocks/-internals/validation/constraints";
import { ERROR_CODES } from "discourse/lib/blocks/-internals/validation/error-codes";
import { formatWithSuggestion } from "discourse/lib/string-similarity";
import type Blocks from "discourse/services/blocks";

/**
 * A `LayoutEntry` widened with the runtime-only fields the soft-failure path
 * stamps onto an entry in permissive mode. These are attached during
 * validation (never authored in a layout), so they live in a local extension
 * rather than on the shared `LayoutEntry`. They mirror the `__failureType` /
 * `__failureReason` shape the live ghost-rendering path already recognises.
 */
interface SoftFailureEntry extends LayoutEntry {
  /** Whether the entry should render (false once it soft-fails). */
  __visible?: boolean;
  /** The failure category recognised by the ghost-rendering path. */
  __failureType?: string;
  /** The human-readable failure message. */
  __failureReason?: string;
  /** The structured, accumulated failure details for per-field display. */
  __failureDetails?: ValidationErrorDetails[];
}

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
    const err = error as Error & {
      path?: string;
      details?: ValidationErrorDetails | ValidationErrorDetails[] | null;
    };
    // Errors with path property need context enrichment
    if (err.path) {
      raiseBlockError(`${errorPrefix}: ${err.message}`, {
        ...context,
        errorPath: buildErrorPath(context.path, err.path),
        // Preserve the structured payload through the re-throw. Without
        // this, args-validation throws lose `code` / `field` / `expected`
        // by the time a consumer catches the wrapped error.
        details: err.details ?? null,
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
 * A composite block (one that declares `parts`) is the exception: it is a
 * container, but its children are synthesized from its parts at render time,
 * so a valid instance carries no explicit `children`. Declared parts therefore
 * satisfy the "must have children" requirement.
 *
 * @param entry - The block entry.
 * @param isContainer - Whether the block is a container.
 * @param hasParts - Whether the block declares composite `parts`.
 * @param blockName - The block name for error messages.
 * @param outletName - The outlet name for error messages.
 * @param context - Error context for raiseBlockError.
 * @returns True if validation passed, false if error was raised.
 */
function validateContainerChildren(
  entry: LayoutEntry,
  isContainer: boolean,
  hasParts: boolean,
  blockName: string,
  outletName: string,
  context: ValidationContext
): boolean {
  const hasChildren = !!entry.children?.length;

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
 * @param blockRef - A child entry's `block` value.
 * @returns The registered block name, or null when it can't be determined.
 */
function childBlockName(
  blockRef: LayoutEntry["block"] | undefined
): string | null {
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
 * @param entry - The parent container entry.
 * @param parentMeta - The parent's resolved block metadata.
 * @param parentName - Parent block name for error messages.
 * @param outletName - The outlet name for error messages.
 * @param context - Error context for raiseBlockError.
 * @returns True if every child is allowed (or nothing to check).
 */
function validateAllowedChildBlocks(
  entry: LayoutEntry,
  parentMeta: BlockMetadata,
  parentName: string,
  outletName: string,
  context: ValidationContext
): boolean {
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
 * @param metadata - Block metadata with constraints/validate.
 * @param resolvedBlock - The resolved block class.
 * @param entry - The block entry.
 * @param blockName - The block name for error messages.
 * @param context - Error context for raiseBlockError (strict mode); null when collecting.
 * @param options - When `options.collect` is provided, violations are appended to it instead of thrown.
 */
function validateBlockConstraints(
  metadata: BlockMetadata | null | undefined,
  resolvedBlock: BlockClass,
  entry: LayoutEntry,
  blockName: string,
  context: ValidationContext | null,
  { collect = null }: { collect?: ValidationError[] | null } = {}
): void {
  if (!metadata?.constraints && !metadata?.validate) {
    return;
  }

  const argsWithDefaults = applyArgDefaults(resolvedBlock, entry.args || {});

  // Append to the collector (accumulate mode) or throw with full context
  // (fail-fast mode), depending on whether a collector was supplied.
  const report = (
    errorPath: string,
    message: string,
    details: ValidationErrorDetails
  ): void => {
    if (collect) {
      collect.push({ message, path: errorPath, details });
    } else {
      raiseBlockError(
        `Invalid block "${blockName}" at ${context?.path} for outlet "${context?.outletName}": ${message}`,
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
    if (customErrors && customErrors.length > 0) {
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
 * @param entry - The block entry whose current `args` to check.
 * @param blockClass - The `@block`-decorated class, or a string block-name ref
 *   (as layout entries carry — `entry.block` is usually the registered name). A
 *   string is resolved to its class via the registry; a ref that resolves to no
 *   registered metadata yields `[]` (nothing to validate against).
 * @param options - Optional `owner` (Ember owner) used by arg validation for
 *   `model:*` `instanceOf` checks.
 * @returns The structured failure details, or an empty array when the entry's
 *   args and constraints all pass.
 */
export function collectEntryFailures(
  entry: LayoutEntry,
  blockClass: BlockClass | string,
  { owner }: Pick<ValidateArgValueOptions, "owner"> = {}
): ValidationErrorDetails[] {
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
  const collector: ValidationError[] = [];
  try {
    validateBlockArgs(entry, resolved, { owner, collect: collector });
  } catch (err: unknown) {
    // `validateBlockArgs` still throws for the "args provided but no schema"
    // case, which collect mode doesn't cover. Surface it as a single detail
    // rather than letting it break the edit.
    if (err instanceof BlockError) {
      // This error carries a single detail (never the accumulated array), so
      // take the first entry if it was somehow wrapped.
      const detail = Array.isArray(err.details) ? err.details[0] : err.details;
      collector.push({
        message: err.message,
        path: "",
        details: detail ?? { code: ERROR_CODES.INVALID_BLOCK },
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

  return collector
    .map((failure) => failure.details)
    .filter((details): details is ValidationErrorDetails => details != null);
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
      {
        ...createValidationContext({
          outletName,
          blockName: name,
          path: context.path ?? "",
          entry: asContextEntry(context.entry),
          callSiteError: context.callSiteError,
          rootLayout: asContextLayout(context.rootLayout),
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
export const VALID_ENTRY_KEYS: readonly string[] = Object.freeze([
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
 * A single soft-failure record logged in permissive mode.
 */
interface LayoutValidationWarning {
  /** The failure message. */
  message: string;
  /** The path to the failing entry. */
  path: string;
  /** The underlying error that triggered the soft failure. */
  error: Error;
  /** The structured, accumulated failure details for per-field display. */
  details: ValidationErrorDetails[];
}

/**
 * Validation context passed through layout validation recursion.
 * Created at the root level and shared across all entries to enable
 * cross-cutting validation (e.g., ID uniqueness across the entire tree).
 */
export interface LayoutValidationContext {
  /** Map of entry IDs to their paths for uniqueness validation. */
  seenIds: Map<string, { path: string }>;
  /**
   * When true, per-entry failures are caught and recorded as soft failures
   * instead of aborting the whole layout.
   */
  permissive?: boolean;
  /**
   * When true, arg validation accumulates every failure into a single
   * synthetic error (used by permissive consumers).
   */
  collect?: boolean;
  /** Soft-failure log populated in permissive mode. */
  warnings?: LayoutValidationWarning[];
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
    } catch (err: unknown) {
      if (context.permissive && (err as Error)?.name === "BlockError") {
        markEntrySoftFailure(entry, err as BlockError);
        context.warnings?.push({
          message: (err as Error).message,
          path: currentPath,
          error: err as Error,
          details: (entry as SoftFailureEntry).__failureDetails ?? [],
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
 * / `__failureReason` shape that the live ghost-rendering path already uses
 * for condition-failed and no-visible-children entries, so it picks the
 * entry up without further plumbing.
 *
 * @param entry - The layout entry to mark.
 * @param err - The `BlockError` describing why the entry failed.
 */
function markEntrySoftFailure(entry: LayoutEntry, err: BlockError): void {
  const softEntry = entry as SoftFailureEntry;
  softEntry.__visible = false;
  softEntry.__failureType = "structural-invalid";
  softEntry.__failureReason = err.message;
  // Always an array for consumer consistency. In permissive/collect mode,
  // `err.details` is already the accumulated list; in strict mode it's a
  // single detail object which we wrap. `null` becomes an empty array so
  // consumers never have to branch on shape.
  softEntry.__failureDetails = Array.isArray(err.details)
    ? err.details
    : err.details
      ? [err.details]
      : [];
}

/** Parameters accepted by {@link validateOneEntry}. */
interface ValidateOneEntryParams {
  /** The block entry to validate. */
  entry: LayoutEntry;
  /** JSON-path style location of this entry in the layout. */
  currentPath: string;
  /** The outlet this entry belongs to. */
  outletName: string;
  /** Service for validating conditions. */
  blocksService: Blocks | undefined;
  /** Where renderBlocks() was called from. */
  callSiteError: Error | null;
  /** The root layout array for error context display. */
  effectiveRootLayout: LayoutEntry[];
  /** The parent container's childArgs schema, if any. */
  parentChildArgsSchema: Record<string, ChildArgSchema> | null;
  /** The parent container's block name for error messages. */
  parentBlockName: string | null;
  /** Current nesting depth for recursion limit checking. */
  depth: number;
  /** Validation context for cross-cutting concerns like ID uniqueness. */
  context: LayoutValidationContext;
}

/**
 * The per-entry validation body, extracted so the outer per-entry
 * try/catch in `validateLayout` is the single boundary between "this
 * entry blew up" and "everything else keeps going". Pure orchestration
 * — the same calls validateLayout used to make inline.
 *
 * @param params - The per-entry validation parameters.
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
}: ValidateOneEntryParams): Promise<void> {
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
 * @param context - Validation context enabling per-entry arg accumulation in permissive/collect mode.
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
  parentBlockName: string | null = null,
  context: LayoutValidationContext | null = null
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
    {
      path,
      entry,
      callSiteError,
      rootLayout,
    }
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
      {
        ...earlyContext,
        details: { code: ERROR_CODES.INVALID_BLOCK },
      }
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
  const collector: ValidationError[] | null = context?.collect ? [] : null;

  // Validate args first. In strict mode this throws on the first bad arg
  // (fail-fast); in collect mode it records every bad arg into `collector`
  // without throwing.
  wrapValidationError(
    () =>
      validateBlockArgs(entry, resolvedBlockClass, {
        owner,
        collect: collector ?? undefined,
      }),
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
    resolvedBlockClass,
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
      details: collector
        .map((e) => e.details)
        .filter((d): d is ValidationErrorDetails => d != null),
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
