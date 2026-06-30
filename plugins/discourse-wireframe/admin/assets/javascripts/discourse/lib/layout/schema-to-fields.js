// @ts-check
/**
 * Maps a block's args schema (with optional `ui` hints) to a flat list of
 * inspector field descriptors that the editor renders via FormKit.
 *
 * The mapper is pure logic and pure data — no Glimmer, no FormKit imports.
 * That keeps it testable in isolation and lets the inspector component stay
 * a thin renderer on top.
 *
 * Default control mapping (overridable via `argDef.ui.control`):
 *
 *   ┌───────────────────────────────────┬────────────────────┐
 *   │ Schema shape                      │ Default control    │
 *   ├───────────────────────────────────┼────────────────────┤
 *   │ string                            │ text               │
 *   │ string + maxLength > 200          │ textarea           │
 *   │ string + enum                     │ select             │
 *   │ number                            │ number             │
 *   │ boolean                           │ toggle             │
 *   │ array (itemType: string)          │ tag-chooser        │
 *   │ any                               │ code               │
 *   └───────────────────────────────────┴────────────────────┘
 *
 * Anything more specific (color picker, image uploader, etc.) is opt-in via
 * the `ui.control` hint on the arg schema. See `VALID_UI_CONTROLS` in
 * `discourse/lib/blocks` for the supported set.
 */

const TEXTAREA_LENGTH_THRESHOLD = 200;
const DEFAULT_GROUP = "General";

/**
 * @typedef {Object} InspectorField
 * @property {string} name - The arg name (key in the args object).
 * @property {string} control - The control type to render. One of
 *   `VALID_UI_CONTROLS` plus `"text"` (the implicit default for unmapped
 *   string args).
 * @property {string} title - Display label for the field.
 * @property {string|null} placeholder
 * @property {string|null} helpText
 * @property {string} group - Section name; defaults to "General".
 * @property {boolean} required
 * @property {*} default - The schema's `default` value, or `undefined`.
 * @property {Array|null} options - For `select` / `radio-group`, the enum
 *   values; otherwise `null`.
 * @property {{arg: string, equals?: *, notEmpty?: boolean}|null} conditional -
 *   Optional show-when-this predicate.
 * @property {Object} schema - The original schema entry, for runtime
 *   validation hooks the renderer may want.
 */

/**
 * Decides which inspector control to render for a single arg, applying the
 * default mapping then layering any `ui.control` override on top.
 *
 * @param {Object} argDef
 * @returns {string}
 */
function pickControl(argDef) {
  // The `image` arg type owns its own inspector control — a custom
  // FormKit field with Upload | URL tabs, an optional dark variant, and
  // a ratio-mismatch warning. The type determines the control; no
  // `ui.control` hint is needed (or accepted) for image args.
  if (argDef.type === "image") {
    return "image";
  }
  if (argDef.ui?.control) {
    return argDef.ui.control;
  }

  switch (argDef.type) {
    case "boolean":
      return "toggle";
    case "number":
      return "number";
    case "any":
      return "code";
    case "richInline":
      // Inline rich text is edited on the canvas via the InplaceTextController.
      // The inspector field shows a read-only summary so authors can see
      // the current content without having a parallel edit surface here.
      return "rich-inline";
    case "array":
      // String arrays map to a tag-chooser; arrays of structured objects
      // (`itemType: "object"` + `itemSchema`) map to the repeatable control,
      // which renders one editable row per item. Anything else falls through
      // to a plain text input.
      if (argDef.itemType === "string") {
        return "tag-chooser";
      }
      if (argDef.itemType === "object") {
        return "repeatable";
      }
      return "text";
    case "string":
    default:
      if (Array.isArray(argDef.enum) && argDef.enum.length > 0) {
        return "select";
      }
      if (argDef.maxLength && argDef.maxLength > TEXTAREA_LENGTH_THRESHOLD) {
        return "textarea";
      }
      return "text";
  }
}

/**
 * Title-cases an arg name (e.g. `ctaLabel` → `Cta Label`) for use as a
 * default field label when the schema doesn't supply `ui.label`.
 *
 * @param {string} name
 * @returns {string}
 */
function defaultTitle(name) {
  return name
    .replace(/([A-Z])/g, " $1")
    .replace(/[-_]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/(?:^|\s)\S/g, (c) => c.toUpperCase());
}

/**
 * Builds the inspector field list for a block's args schema.
 *
 * Args with `ui.hidden === true` are omitted entirely. The order of the
 * returned list matches the order keys appear in the schema, so block
 * authors control field ordering by ordering their schema.
 *
 * @param {Object|null|undefined} schema - The block's args schema (the value
 *   of `metadata.args`).
 * @returns {InspectorField[]}
 */
export function schemaToFields(schema) {
  if (!schema || typeof schema !== "object") {
    return [];
  }

  const fields = [];
  for (const [name, argDef] of Object.entries(schema)) {
    if (argDef?.ui?.hidden === true) {
      continue;
    }

    const ui = argDef.ui || {};
    fields.push({
      name,
      control: pickControl(argDef),
      title: ui.label || defaultTitle(name),
      placeholder: ui.placeholder ?? null,
      helpText: ui.helpText ?? null,
      group: ui.group || DEFAULT_GROUP,
      required: argDef.required === true,
      default: argDef.default,
      options: Array.isArray(argDef.enum) ? [...argDef.enum] : null,
      optionIcons: ui.optionIcons ?? null,
      conditional: ui.conditional ?? null,
      schema: argDef,
    });
  }
  return fields;
}

/**
 * Infers a best-effort args schema from a values object. Used as a fallback
 * for blocks that receive args at render time but don't declare an `args`
 * schema in their `@block(...)` decorator (so we have nothing to map to
 * inspector fields). Each value's runtime type drives the inferred type:
 *
 *   - strings, numbers, booleans → matching primitive types
 *   - everything else (arrays, objects, null) → `any`
 *
 * Block authors who want richer inspectors (color pickers, image uploaders,
 * grouping, conditional fields) declare a real schema with `ui:` hints in
 * their decorator. The fallback keeps the editing pipeline working
 * against existing themes that haven't declared one.
 *
 * @param {Object|null|undefined} values
 * @returns {Object} A synthesised args schema in the same shape as the
 *   value of `metadata.args`.
 */
export function inferSchemaFromValues(values) {
  if (!values || typeof values !== "object") {
    return {};
  }

  const schema = {};
  for (const [name, value] of Object.entries(values)) {
    schema[name] = { type: inferType(value) };
  }
  return schema;
}

function inferType(value) {
  if (typeof value === "string") {
    return "string";
  }
  if (typeof value === "number") {
    return "number";
  }
  if (typeof value === "boolean") {
    return "boolean";
  }
  return "any";
}

/**
 * Groups a field list by `group` while preserving each group's first-seen
 * order. Used by the inspector to render `<form.Section>` headers.
 *
 * @param {InspectorField[]} fields
 * @returns {Array<{group: string, fields: InspectorField[]}>}
 */
export function groupFields(fields) {
  const groups = new Map();
  for (const field of fields) {
    if (!groups.has(field.group)) {
      groups.set(field.group, []);
    }
    groups.get(field.group).push(field);
  }
  return [...groups.entries()].map(([group, list]) => ({
    group,
    fields: list,
  }));
}

/**
 * Builds a FormKit `@validation` rule string from an inspector field's
 * schema constraints. Returns `undefined` when nothing in the schema
 * maps to a rule, so callers can omit the prop entirely. The rule
 * syntax is FormKit's pipe-joined form parsed by `ValidationParser`
 * (`frontend/discourse/app/form-kit/lib/validation-parser.js`):
 *
 *   - `required` — emitted when `field.required === true`.
 *   - `length:<min>,<max>` — emitted only when BOTH `minLength` and
 *     `maxLength` are declared on the arg schema; FormKit's `length`
 *     rule expects both bounds.
 *   - `between:<min>,<max>` — emitted only when BOTH `min` and `max`
 *     are declared on a numeric arg.
 *
 * We deliberately don't fake the missing bound (no synthetic
 * `Number.MAX_SAFE_INTEGER`): a one-sided constraint is rarer than
 * "the schema author forgot the other side", and a fake bound would
 * silently accept overlong inputs while looking like validation.
 *
 * @param {InspectorField} field
 * @returns {string|undefined}
 */
export function buildValidationRule(field) {
  const rules = [];
  if (field.required) {
    rules.push("required");
  }
  const schema = field.schema ?? {};
  if (schema.minLength != null && schema.maxLength != null) {
    rules.push(`length:${schema.minLength},${schema.maxLength}`);
  }
  if (schema.min != null && schema.max != null) {
    rules.push(`between:${schema.min},${schema.max}`);
  }
  return rules.length ? rules.join("|") : undefined;
}

/**
 * Evaluates a field's `conditional` predicate against the current arg
 * values. Returns `true` (visible) when no predicate is set.
 *
 * @param {InspectorField} field
 * @param {Object} values - Current arg values keyed by arg name.
 * @returns {boolean}
 */
export function isFieldVisible(field, values) {
  const predicate = field.conditional;
  if (!predicate) {
    return true;
  }
  const target = values?.[predicate.arg];
  if (predicate.notEmpty === true) {
    return target != null && target !== "" && target !== false;
  }
  if (Object.prototype.hasOwnProperty.call(predicate, "equals")) {
    return target === predicate.equals;
  }
  return true;
}
