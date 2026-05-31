// @ts-check
/**
 * Translates a structured validation error detail (emitted by the
 * blocks API — `frontend/discourse/app/lib/blocks/-internals/validation/error-codes.js`)
 * into a short, author-friendly i18n message suitable for inline
 * display under an inspector field or in the errors pill.
 *
 * The blocks API's raw `details.message` is the developer string from
 * `raiseBlockError()` (e.g. "Arg \"ctaHref\" value \"#\" does not match
 * required pattern /^https:\/\//"). That's the right thing for an
 * `api.renderBlocks` consumer reading the console — but in the editor
 * we want "Doesn't match the expected format." next to the CTA href
 * field. This helper does that translation.
 *
 * Unknown codes fall through to the raw message — better than nothing,
 * and a forcing-function to add an i18n key when a new code lands.
 *
 * @module discourse/plugins/discourse-wireframe/discourse/lib/friendly-error-message
 */

import { ERROR_CODES } from "discourse/lib/blocks/-internals/validation/error-codes";
import { i18n } from "discourse-i18n";

/**
 * Joins a list of arg names into a quoted, comma-separated string for
 * constraint-violation messages (e.g. `"a", "b", "c"`).
 *
 * @param {string[]|undefined|null} fields
 * @returns {string}
 */
function formatFieldList(fields) {
  if (!Array.isArray(fields) || fields.length === 0) {
    return "";
  }
  return fields.map((f) => `"${f}"`).join(", ");
}

/**
 * Builds the inspector-side localized message for a constraint
 * violation. Picks a constraint-type-specific key so the wording
 * matches each constraint's semantics ("set at least one of …" vs
 * "set exactly one of …").
 *
 * @param {Object} details
 * @returns {string}
 */
function constraintMessage(details) {
  const constraint = details.expected?.constraint;
  const fields = formatFieldList(details.expected?.fields);
  switch (constraint) {
    case "atLeastOne":
      return i18n("wireframe.inspector.errors.constraint_at_least_one", {
        fields,
      });
    case "exactlyOne":
      return i18n("wireframe.inspector.errors.constraint_exactly_one", {
        fields,
      });
    case "atMostOne":
      return i18n("wireframe.inspector.errors.constraint_at_most_one", {
        fields,
      });
    case "allOrNone":
      return i18n("wireframe.inspector.errors.constraint_all_or_none", {
        fields,
      });
    case "requires":
      return i18n("wireframe.inspector.errors.constraint_requires", { fields });
    default:
      return i18n("wireframe.inspector.errors.constraint_generic");
  }
}

/**
 * Returns a short, author-friendly message for a structured validation
 * error detail. Falls back to `details.message` (the developer string)
 * when no friendly equivalent is registered for the code.
 *
 * @param {Object|null|undefined} details - One entry from
 *   `entry.__failureDetails`. Shape: `{ code, field?, value?, expected? }`.
 * @returns {string}
 */
export function friendlyErrorMessage(details) {
  if (!details?.code) {
    return details?.message ?? "";
  }
  switch (details.code) {
    case ERROR_CODES.REQUIRED_MISSING:
      return i18n("wireframe.inspector.errors.required");
    case ERROR_CODES.TYPE_MISMATCH:
      return i18n("wireframe.inspector.errors.type");
    case ERROR_CODES.PATTERN_MISMATCH:
      return i18n("wireframe.inspector.errors.pattern");
    case ERROR_CODES.ENUM_MISMATCH:
      return i18n("wireframe.inspector.errors.enum", {
        allowed: formatFieldList(details.expected?.enum),
      });
    case ERROR_CODES.MIN_LENGTH:
      return i18n("wireframe.inspector.errors.min_length", {
        min: details.expected?.minLength,
      });
    case ERROR_CODES.MAX_LENGTH:
      return i18n("wireframe.inspector.errors.max_length", {
        max: details.expected?.maxLength,
      });
    case ERROR_CODES.MIN:
      return i18n("wireframe.inspector.errors.min", {
        min: details.expected?.min,
      });
    case ERROR_CODES.MAX:
      return i18n("wireframe.inspector.errors.max", {
        max: details.expected?.max,
      });
    case ERROR_CODES.UNKNOWN_ARG:
      return i18n("wireframe.inspector.errors.unknown_arg");
    case ERROR_CODES.CONSTRAINT_VIOLATION:
      return constraintMessage(details);
    case ERROR_CODES.INVALID_CHILDREN:
      return i18n("wireframe.inspector.errors.invalid_children");
    case ERROR_CODES.UNREGISTERED_BLOCK:
      return i18n("wireframe.inspector.errors.unregistered_block");
    case ERROR_CODES.DUPLICATE_ID:
      return i18n("wireframe.inspector.errors.duplicate_id");
    case ERROR_CODES.INVALID_BLOCK:
      return i18n("wireframe.inspector.errors.invalid_block");
    default:
      return details.message ?? "";
  }
}
