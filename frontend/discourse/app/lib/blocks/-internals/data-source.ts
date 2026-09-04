import type { BlockDataSource } from "discourse/blocks/types";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

const BLOCK_DATA_SOURCE = Symbol("BlockDataSource");
const VALID_SOURCE_KEYS = Object.freeze([
  "name",
  "resolve",
  "hydrate",
  "batch",
]);
const VALID_BATCH_KEYS = Object.freeze(["request", "resolve", "extract"]);

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype
  );
}

function validateUnknownKeys(
  value: Record<string, unknown>,
  validKeys: readonly string[],
  label: string
): void {
  const unknownKeys = Object.keys(value).filter(
    (key) => !validKeys.includes(key)
  );

  if (unknownKeys.length > 0) {
    const suggestions = unknownKeys
      .map((key) => formatWithSuggestion(key, validKeys))
      .join(", ");
    raiseBlockError(
      `${label} has unknown key(s): ${suggestions}. ` +
        `Valid keys are: ${validKeys.join(", ")}.`
    );
  }
}

/**
 * Defines a reusable source of block data.
 *
 * The source is validated, branded, and frozen so it can be safely shared by
 * multiple block declarations. A source may resolve individual descriptors,
 * batch descriptors together, or support both strategies.
 *
 * @param config - The data-source functions and optional diagnostic name.
 * @returns A validated, immutable block data source.
 */
export function defineBlockDataSource(
  config: BlockDataSource
): BlockDataSource {
  if (!isPlainObject(config)) {
    raiseBlockError("Block data source config must be an object.");
  }

  validateUnknownKeys(config, VALID_SOURCE_KEYS, "Block data source config");

  if (
    config.name !== undefined &&
    (typeof config.name !== "string" || config.name.trim() === "")
  ) {
    raiseBlockError('Block data source "name" must be a non-empty string.');
  }

  if (config.resolve === undefined && config.batch === undefined) {
    raiseBlockError('Block data source must declare "resolve" or "batch".');
  }

  for (const key of ["resolve", "hydrate"] as const) {
    if (config[key] !== undefined && typeof config[key] !== "function") {
      raiseBlockError(`Block data source "${key}" must be a function.`);
    }
  }

  let batch = config.batch;
  if (batch !== undefined) {
    if (!isPlainObject(batch)) {
      raiseBlockError('Block data source "batch" must be an object.');
    }

    validateUnknownKeys(batch, VALID_BATCH_KEYS, 'Block data source "batch"');

    for (const key of VALID_BATCH_KEYS) {
      if (typeof batch[key] !== "function") {
        raiseBlockError(
          `Block data source "batch.${key}" is required and must be a function.`
        );
      }
    }

    batch = Object.freeze({ ...batch });
  }

  const source = {
    ...config,
    ...(batch ? { batch } : {}),
  };
  Object.defineProperty(source, BLOCK_DATA_SOURCE, { value: true });

  return Object.freeze(source) as BlockDataSource;
}

/**
 * Reports whether a value was created by {@link defineBlockDataSource}.
 *
 * @param value - The value to inspect.
 * @returns `true` only for a branded block data source.
 */
export function isBlockDataSource(value: unknown): value is BlockDataSource {
  return (
    value !== null &&
    typeof value === "object" &&
    Object.hasOwn(value, BLOCK_DATA_SOURCE) &&
    value[BLOCK_DATA_SOURCE] === true
  );
}
