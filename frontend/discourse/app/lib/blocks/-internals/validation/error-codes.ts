/**
 * Closed enum of validation error codes for structured block-error
 * payloads. Curated — adding a new throw category means adding a code
 * here first.
 *
 * The blocks API has two consumers:
 *
 *   1. Strict / programmatic (`api.renderBlocks`, tests, hydrators):
 *      one human-readable message is enough; the call stack and the
 *      block name are the actionable signal.
 *
 *   2. Field-level error consumers: need to know which **field** failed,
 *      what was provided, and what was expected, so they can render the
 *      error against the offending input.
 *
 * The `code` enumerates the failure mode in a way a consumer can pivot
 * on (i18n key lookup, icon choice). The companion `details` payload
 * (assembled at the throw site) carries the `field`, `value`, and
 * `expected.*` fields those consumers need.
 */

export const ERROR_CODES = Object.freeze({
  // Args attributable to a single field.
  REQUIRED_MISSING: "required-missing",
  TYPE_MISMATCH: "type-mismatch",
  PATTERN_MISMATCH: "pattern-mismatch",
  ENUM_MISMATCH: "enum-mismatch",
  MIN_LENGTH: "min-length",
  MAX_LENGTH: "max-length",
  MIN: "min",
  MAX: "max",
  UNKNOWN_ARG: "unknown-arg",
  // Cross-field / block-level. No single `field`; consumers surface
  // these as block-level errors rather than against a specific input.
  CONSTRAINT_VIOLATION: "constraint-violation",
  INVALID_CHILDREN: "invalid-children",
  UNREGISTERED_BLOCK: "unregistered-block",
  DUPLICATE_ID: "duplicate-id",
  // Entry structure. The entry object itself is malformed — an unknown
  // top-level key, a field of the wrong type, or a badly-formatted id —
  // independent of any block's args. Typically a hand-authored typo.
  UNKNOWN_ENTRY_KEY: "unknown-entry-key",
  INVALID_ENTRY_TYPE: "invalid-entry-type",
  INVALID_ENTRY_ID: "invalid-entry-id",
  // Catch-all. Use only when the failure doesn't fit any of the above
  // and the best move is to display the raw message.
  INVALID_BLOCK: "invalid-block",
} as const);

/** One of the {@link ERROR_CODES} values. */
export type ErrorCode = (typeof ERROR_CODES)[keyof typeof ERROR_CODES];
