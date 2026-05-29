// @ts-check
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
 *   2. The visual editor: needs to know which **field** failed, what
 *      was provided, and what was expected, so it can render the
 *      error under the offending control in the inspector.
 *
 * The `code` enumerates the failure mode in a way the editor can pivot
 * on (i18n key lookup, icon choice). The companion `details` payload
 * (assembled at the throw site) carries the `field`, `value`, and
 * `expected.*` fields the editor needs.
 *
 * @module discourse/lib/blocks/-internals/validation/error-codes
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
  // Cross-field / block-level. No single `field`; the editor surfaces
  // these in the top-of-inspector errors pill rather than under a
  // specific control.
  CONSTRAINT_VIOLATION: "constraint-violation",
  INVALID_CHILDREN: "invalid-children",
  UNREGISTERED_BLOCK: "unregistered-block",
  DUPLICATE_ID: "duplicate-id",
  // Catch-all. Use only when the failure doesn't fit any of the above
  // and the editor's best move is to display the raw message.
  INVALID_BLOCK: "invalid-block",
});
