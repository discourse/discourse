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
 * Module: `discourse/plugins/discourse-wireframe/discourse/lib/friendly-error-message`
 */

import type { ArgSchema, LayoutEntry } from "discourse/blocks/types";
import type { ValidationErrorDetails } from "discourse/lib/blocks/-internals/validation/args";
import { ERROR_CODES } from "discourse/lib/blocks/-internals/validation/error-codes";
import { i18n } from "discourse-i18n";

type FriendlyValidationExpected = Record<string, unknown> & {
  /** Constraint kind associated with the failure. */
  constraint?: string;
  /** Allowed enum values rendered in a friendly message. */
  enum?: string[];
  /** Argument names involved in a constraint failure. */
  fields?: string[];
  /** Maximum allowed value. */
  max?: number;
  /** Maximum allowed length. */
  maxLength?: number;
  /** Minimum allowed value. */
  min?: number;
  /** Minimum allowed length. */
  minLength?: number;
  /** Invalid entry key. */
  key?: string;
  /** Known entry keys offered as alternatives. */
  keys?: string[];
};

// TODO(devxp-typescript-pending): use `ValidationErrorDetails` directly once
// core declares the fallback `message` and typed `expected` fields it emits.
type FriendlyValidationDetail = ValidationErrorDetails & {
  /** Structured values used to interpolate a friendly message. */
  expected?: FriendlyValidationExpected;
  /** Developer message used when no friendly translation exists. */
  message?: string;
};

// TODO(devxp-typescript-pending): import core's type directly once it exports
// the soft-failure layout-entry shape used by permissive validation.
/** Layout entry carrying the soft-validation stamps added by core. */
export interface FriendlyValidatedEntry extends LayoutEntry {
  /** Structured validation failures accumulated for the entry. */
  __failureDetails?: FriendlyValidationDetail[];
  /** Human-readable fallback validation message. */
  __failureReason?: string;
}

/** One author-facing validation message with a stable list key. */
export type FriendlyEntryMessage = {
  /** Stable identifier derived from the validation failure. */
  id: string;
  /** Localized message shown to the author. */
  text: string;
};

type PendingMessageLine = {
  /** Optional stable identifier for a block-level failure. */
  id?: string;
  /** Friendly field labels grouped under this message. */
  fields: string[];
  /** Localized failure message. */
  message: string;
  /** Raw field keys used to create a stable identifier. */
  rawFields: string[];
};

/**
 * Joins a list of arg names into a quoted, comma-separated string for
 * constraint-violation messages (e.g. `"a", "b", "c"`).
 *
 * @param fields - Argument names involved in the constraint.
 * @returns Quoted, comma-separated argument names.
 */
function formatFieldList(fields: string[] | null | undefined): string {
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
 * @param details - Structured constraint failure details.
 * @returns Localized constraint failure message.
 */
function constraintMessage(details: FriendlyValidationDetail): string {
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
 * @param details - One structured failure from the entry's validation stamps.
 * @returns Localized author-facing message.
 */
export function friendlyErrorMessage(
  details: FriendlyValidationDetail | null | undefined
): string {
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
    case ERROR_CODES.UNKNOWN_ENTRY_KEY:
      return i18n("wireframe.inspector.errors.unknown_entry_key", {
        keys: formatFieldList(details.expected?.keys),
      });
    case ERROR_CODES.INVALID_ENTRY_TYPE:
      return i18n("wireframe.inspector.errors.invalid_entry_type", {
        key: details.expected?.key,
      });
    case ERROR_CODES.INVALID_ENTRY_ID:
      return i18n("wireframe.inspector.errors.invalid_entry_id");
    case ERROR_CODES.INVALID_BLOCK:
      return i18n("wireframe.inspector.errors.invalid_block");
    default:
      return details.message ?? "";
  }
}

/**
 * Returns the author-friendly messages for a single failing entry, derived
 * from its structured `__failureDetails` stamps.
 *
 * Unlike the inspector — where a message renders directly under the field
 * it belongs to, so the field is implied by position — a standalone list
 * has no such context: three fields each "Required." would be three
 * identical, useless lines. So field-scoped details are named by their
 * field, using the same `ui.label` the inspector shows (falling back to
 * the raw arg key), and details that share the same rendered message are
 * collapsed into one line enumerating their fields (e.g. "Title, Heading:
 * Required."). Block-level details (constraint violations, unregistered
 * blocks) carry no field and always stand alone; their messages already
 * name any fields they involve. First-seen order is preserved.
 *
 * Falls back to the entry's raw `__failureReason` when no structured
 * details are present. That happens in two cases: the permissive
 * validator stamped an empty `__failureDetails` array (its `err.details`
 * was null), or the entry was validated in a strict-mode layer, which
 * only ever writes `__failureReason` (the structured details are a
 * session-draft-layer thing — see
 * `frontend/discourse/app/lib/blocks/-internals/validation/layout.js`'s
 * `markEntrySoftFailure`). Returning the raw reason keeps the failure
 * visible rather than dropping it silently.
 *
 * Each message carries a stable, content-derived `id` (unique within the
 * entry, so a consumer can key a list on it without falling back to array
 * index): the raw field keys for a field-scoped line, or the error code plus
 * constraint sub-type for a block-level one.
 *
 * @param entry - A layout entry carrying validator stamps.
 * @param argsSchema - The block's args schema (each arg's
 *   `ui.label` supplies the friendly field name); the raw key is used when
 *   absent.
 * @returns Author-facing messages with stable identifiers.
 */
export function friendlyEntryMessages(
  entry: FriendlyValidatedEntry,
  argsSchema?: Record<string, ArgSchema> | null
): FriendlyEntryMessage[] {
  const details = entry.__failureDetails;
  if (!Array.isArray(details) || !details.length) {
    // TODO(devxp-typescript-pending): `__failureReason` is optional, but the
    // original runtime emits the reason line unconditionally (text may be
    // `undefined`). Cast to preserve that exact shape until the soft-failure
    // entry type guarantees a reason here.
    return [{ id: "reason", text: entry.__failureReason as string }];
  }

  const lines: PendingMessageLine[] = [];
  const groupIndexByMessage = new Map<string, number>();
  for (const detail of details) {
    const message = friendlyErrorMessage(detail);
    if (!detail.field) {
      // Block-level: `code` plus the constraint sub-type is unique per entry
      // (a block declares at most one constraint of each type).
      lines.push({
        id: `code:${detail.code}:${detail.expected?.constraint ?? ""}`,
        message,
        fields: [],
        rawFields: [],
      });
      continue;
    }
    const label = argsSchema?.[detail.field]?.ui?.label ?? detail.field;
    const existing = groupIndexByMessage.get(message);
    if (existing === undefined) {
      groupIndexByMessage.set(message, lines.length);
      lines.push({ message, fields: [label], rawFields: [detail.field] });
    } else {
      lines[existing]!.fields.push(label);
      lines[existing]!.rawFields.push(detail.field);
    }
  }

  return lines.map(({ id, message, fields, rawFields }) =>
    fields.length
      ? {
          // Fields partition into groups, so the joined raw keys are unique
          // across a block's field-scoped lines.
          id: `field:${rawFields.join(",")}`,
          text: i18n("wireframe.inspector.errors.field_scoped", {
            field: fields.join(", "),
            message,
          }),
        }
      : { id: id!, text: message }
  );
}
