/**
 * Block-specific arg validation.
 *
 * This module adapts the shared arg validation utilities from args.ts
 * for use with blocks. Key differences from condition arg validation:
 * - Supports "default" values (conditions don't use defaults)
 * - Validates "required + default" contradiction
 * - Supports `ui` hints that advise how each arg is presented for editing
 *   (no runtime effect; pure metadata)
 * - Supports childArgs with "unique" property
 */
import type {
  ArgSchema,
  ArgUiGroup,
  ChildArgSchema,
  LayoutEntry,
} from "discourse/blocks/types";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import {
  BlockError,
  raiseBlockError,
} from "discourse/lib/blocks/-internals/error";
import type { BlockClass } from "discourse/lib/blocks/-internals/types";
import {
  VALID_ARG_SCHEMA_PROPERTIES,
  validateArgName,
  validateArgsAgainstSchema,
  validateArgSchemaEntry,
  validateArgValue,
  type ValidateArgValueOptions,
} from "discourse/lib/blocks/-internals/validation/args";

/**
 * Valid `ui.control` values. Advise which input type an arg should be edited
 * with. Adding a new control requires both this list (so the validator
 * accepts it at decoration time) and a corresponding renderer in whatever
 * consumes the hint. The list is also re-exported from
 * `discourse/lib/blocks` so plugin and theme authors can reference it.
 */
export const VALID_UI_CONTROLS = Object.freeze([
  "text",
  "textarea",
  "number",
  "toggle",
  "select",
  "radio-group",
  "color",
  "icon",
  "emoji",
  "url",
  "rich-text",
  "rich-inline",
  "code",
  "category-select",
  "tag-select",
  "user-select",
  "group-select",
  "topic-select",
  // For an array of structured items (`itemType: "object"` + `itemSchema`):
  // a consumer renders one editable row per item, each row built from the
  // item field schema.
  "repeatable",
  // A numeric value with an optional unit selector and inline slider.
  "dimension",
  // A numeric value with decrement / increment buttons.
  "stepper",
  // A single-select button group (an alternative presentation of an enum).
  "segmented",
]);

/**
 * Valid properties on the `ui` hint object. Anything else triggers a
 * decoration-time error so typos surface immediately.
 */
const VALID_UI_PROPERTIES = Object.freeze([
  "control",
  "label",
  "placeholder",
  "helpText",
  "emptyPrompt",
  "group",
  "hidden",
  "conditional",
  "optionIcons",
  "optionLabels",
  // Variant hint for a `richInline` arg ("plain" / "heading" / "paragraph") —
  // selects the allowed marks / line breaks for in-session rich-text editing.
  // An opaque string to the core validator; consumers map it to their own
  // editing configuration.
  "schema",
  // Numeric-control configuration: the allowed units a value may carry, the
  // default unit, the increment step, and whether to show an inline slider.
  "units",
  "unit",
  "step",
  "slider",
]);

/**
 * Valid properties on the `ui.conditional` predicate object.
 */
const VALID_UI_CONDITIONAL_PROPERTIES = Object.freeze([
  "arg",
  "equals",
  "notEmpty",
  "oneOf",
]);

/**
 * Valid properties for block arg schema definitions. Extends the shared
 * `VALID_ARG_SCHEMA_PROPERTIES` with `ui` so blocks can opt into edit-form
 * hints without polluting the condition arg schema (which has none).
 */
export const VALID_BLOCK_ARG_SCHEMA_PROPERTIES = Object.freeze([
  ...VALID_ARG_SCHEMA_PROPERTIES,
  "ui",
]);

/**
 * Valid properties for childArgs schema definitions.
 * Includes block arg properties plus "unique" for sibling uniqueness validation.
 */
export const VALID_CHILD_ARG_SCHEMA_PROPERTIES: readonly string[] =
  Object.freeze([...VALID_BLOCK_ARG_SCHEMA_PROPERTIES, "unique"]);

/**
 * Validates the `ui` hint object on a block arg.
 *
 * The `ui` field is purely advisory presentation metadata — it never affects
 * runtime behaviour of the block itself. We still validate it at decoration
 * time so authors get fast feedback on typos and unsupported controls instead
 * of silently-broken inputs later.
 *
 * @param uiDef - The value of `ui` from the arg schema (any type — we
 *   handle non-objects defensively).
 * @param argName - The arg name, for error messages.
 * @param blockName - The block name, for error messages.
 * @param argLabel - "arg" or "childArgs arg", for error messages.
 * @param siblingSchema - Arguments available to visibility predicates.
 * @param groups - Descriptors shared by fields in this schema.
 */
function validateUIHints(
  uiDef,
  argName,
  blockName,
  argLabel,
  siblingSchema: Record<string, ArgSchema>,
  groups: Map<string, ArgUiGroup>
) {
  if (uiDef === undefined) {
    return;
  }

  if (uiDef === null || typeof uiDef !== "object" || Array.isArray(uiDef)) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui" value. Must be an object.`
    );
  }

  const unknownProps = Object.keys(uiDef).filter(
    (prop) => !VALID_UI_PROPERTIES.includes(prop)
  );
  if (unknownProps.length > 0) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has unknown ui properties: ${unknownProps.join(", ")}. ` +
        `Valid ui properties are: ${VALID_UI_PROPERTIES.join(", ")}.`
    );
  }

  if (uiDef.control !== undefined) {
    if (typeof uiDef.control !== "string") {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.control" value. Must be a string.`
      );
    }
    if (!VALID_UI_CONTROLS.includes(uiDef.control)) {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.control" value "${uiDef.control}". ` +
          `Valid controls are: ${VALID_UI_CONTROLS.join(", ")}.`
      );
    }
  }

  for (const prop of [
    "label",
    "placeholder",
    "helpText",
    "emptyPrompt",
    "unit",
    "schema",
  ]) {
    if (uiDef[prop] !== undefined && typeof uiDef[prop] !== "string") {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.${prop}" value. Must be a string.`
      );
    }
  }

  validateUIGroup(uiDef.group, argName, blockName, groups);

  for (const prop of ["hidden", "slider"]) {
    if (uiDef[prop] !== undefined && typeof uiDef[prop] !== "boolean") {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.${prop}" value. Must be a boolean.`
      );
    }
  }

  if (uiDef.step !== undefined && typeof uiDef.step !== "number") {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.step" value. Must be a number.`
    );
  }

  if (uiDef.units !== undefined) {
    if (
      !Array.isArray(uiDef.units) ||
      uiDef.units.some((unit) => typeof unit !== "string")
    ) {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.units" value. Must be an array of strings.`
      );
    }
  }

  if (uiDef.conditional !== undefined) {
    validateUIConditional(
      uiDef.conditional,
      argName,
      blockName,
      argLabel,
      siblingSchema
    );
  }

  if (uiDef.optionIcons !== undefined) {
    validateUIOptionIcons(uiDef.optionIcons, argName, blockName, argLabel);
  }

  if (uiDef.optionLabels !== undefined) {
    validateUIOptionLabels(uiDef.optionLabels, argName, blockName, argLabel);
  }
}

function validateUIGroup(
  group: unknown,
  argName: string,
  blockName: string,
  groups: Map<string, ArgUiGroup>
): void {
  if (group === undefined || typeof group === "string") {
    return;
  }
  if (
    !group ||
    typeof group !== "object" ||
    Array.isArray(group) ||
    !("name" in group) ||
    typeof group.name !== "string" ||
    !group.name.trim() ||
    !("label" in group) ||
    typeof group.label !== "string" ||
    !group.label.trim() ||
    !("collapsed" in group) ||
    typeof group.collapsed !== "boolean" ||
    Object.keys(group).some(
      (key) => !["name", "label", "collapsed"].includes(key)
    )
  ) {
    raiseBlockError(
      `Block "${blockName}": arg "${argName}" has invalid "ui.group". Must be a string or { name, label, collapsed } descriptor.`
    );
  }
  const descriptor = {
    name: group.name,
    label: group.label,
    collapsed: group.collapsed,
  };
  const previous = groups.get(descriptor.name);
  if (
    previous &&
    (previous.label !== descriptor.label ||
      previous.collapsed !== descriptor.collapsed)
  ) {
    raiseBlockError(
      `Block "${blockName}": conflicting "ui.group" descriptors for "${descriptor.name}".`
    );
  }
  groups.set(descriptor.name, descriptor);
}

function validateUIOptionLabels(optionLabels, argName, blockName, argLabel) {
  if (
    optionLabels === null ||
    typeof optionLabels !== "object" ||
    Array.isArray(optionLabels)
  ) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.optionLabels" value. Must be an object mapping enum values to display labels.`
    );
  }
  for (const [key, value] of Object.entries(optionLabels)) {
    if (typeof value !== "string" || value.length === 0) {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.optionLabels.${key}". Must be a non-empty string.`
      );
    }
  }
}

/**
 * Validates `ui.optionIcons` — an optional `{ [enumValue]: iconName }`
 * map that lets a radio-group / select control render an icon in
 * place of each enum value's text label. Both keys and values must be
 * strings; the renderer skips any key that's missing from the icon
 * registry at render time.
 *
 * Decorator-time validation catches typos and bad shapes early. We
 * intentionally don't cross-check the keys against the arg's `enum` —
 * the schema validator may not have access to the enum list at this
 * point in the validation sequence, and a stray key just no-ops at
 * render time.
 */
function validateUIOptionIcons(optionIcons, argName, blockName, argLabel) {
  if (
    optionIcons === null ||
    typeof optionIcons !== "object" ||
    Array.isArray(optionIcons)
  ) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.optionIcons" value. Must be an object mapping enum values to icon names.`
    );
  }
  for (const [key, value] of Object.entries(optionIcons)) {
    if (typeof value !== "string" || value.length === 0) {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.optionIcons.${key}". Must be a non-empty string (icon name).`
      );
    }
  }
}

/**
 * Validates field visibility predicates. Compound predicates cannot nest and
 * each leaf must reference a declared argument with exactly one comparator.
 * Standalone equals/notEmpty predicates retain their existing semantics.
 */
function validateUIConditional(
  conditional: unknown,
  argName: string,
  blockName: string,
  argLabel: string,
  siblingSchema: Record<string, ArgSchema>,
  compoundLeaf = false
): void {
  if (
    conditional === null ||
    typeof conditional !== "object" ||
    Array.isArray(conditional)
  ) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.conditional" value. Must be an object.`
    );
  }

  if ("all" in conditional) {
    if (
      compoundLeaf ||
      Object.keys(conditional).length !== 1 ||
      !Array.isArray(conditional.all) ||
      !conditional.all.length
    ) {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.conditional.all". Must contain a non-empty list of non-nested leaf predicates.`
      );
    }
    for (const leaf of conditional.all) {
      validateUIConditional(
        leaf,
        argName,
        blockName,
        argLabel,
        siblingSchema,
        true
      );
    }
    return;
  }

  const unknownProps = Object.keys(conditional).filter(
    (prop) => !VALID_UI_CONDITIONAL_PROPERTIES.includes(prop)
  );
  if (unknownProps.length > 0) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has unknown "ui.conditional" properties: ${unknownProps.join(", ")}. ` +
        `Valid properties are: ${VALID_UI_CONDITIONAL_PROPERTIES.join(", ")}.`
    );
  }

  if (
    !("arg" in conditional) ||
    typeof conditional.arg !== "string" ||
    conditional.arg === ""
  ) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.conditional.arg" value. Must be a non-empty string.`
    );
  }

  if (
    "notEmpty" in conditional &&
    conditional.notEmpty !== undefined &&
    typeof conditional.notEmpty !== "boolean"
  ) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.conditional.notEmpty" value. Must be a boolean.`
    );
  }

  if ("oneOf" in conditional || compoundLeaf) {
    const comparators = ["equals", "notEmpty", "oneOf"].filter((key) =>
      Object.hasOwn(conditional, key)
    );
    if (comparators.length !== 1) {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.conditional". A leaf must specify exactly one comparator.`
      );
    }
    if (
      "oneOf" in conditional &&
      (!Array.isArray(conditional.oneOf) || !conditional.oneOf.length)
    ) {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.conditional.oneOf". Must be a non-empty array.`
      );
    }
    if (!Object.hasOwn(siblingSchema, conditional.arg)) {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has an unknown sibling "${conditional.arg}" in "ui.conditional".`
      );
    }
    return;
  }

  // The predicate needs at least one comparator. Without `equals` or
  // `notEmpty` we have no rule to evaluate against the referenced arg.
  if (
    !("equals" in conditional && conditional.equals !== undefined) &&
    !("notEmpty" in conditional && conditional.notEmpty !== undefined)
  ) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has invalid "ui.conditional" value. ` +
        `Must specify at least one of "equals" or "notEmpty".`
    );
  }
}

/**
 * Validates block-specific default value rules:
 * - "required + default" is contradictory (an arg with a default is never missing)
 * - Default value must match the arg's type schema
 *
 * @param argDef - The argument definition.
 * @param argName - The argument name.
 * @param blockName - Block name for error messages.
 * @param argLabel - Label for error messages (e.g., "childArgs arg").
 */
function validateBlockDefaultValue(
  argDef: ArgSchema,
  argName: string,
  blockName: string,
  argLabel = "arg"
): void {
  // Check for required + default contradiction (value-based, not presence-based)
  // An arg with required: false + default is valid, so we check required === true
  if (argDef.required === true && argDef.default !== undefined) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has both "required: true" and "default". ` +
        `These options are contradictory - an arg with a default value is never missing.`
    );
  }

  if (argDef.default !== undefined) {
    const defaultError = validateArgValue(argDef.default, argDef, argName, {
      contextName: blockName,
      contextType: "Block",
    });
    if (defaultError) {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid default value. ${defaultError.message}`
      );
    }
  }
}

/**
 * Validates the arg schema definition passed to the `@block` decorator.
 * Enforces strict schema format - unknown properties are not allowed.
 *
 * @param argsSchema - The args schema object from decorator options.
 * @param blockName - Block name for error messages.
 * @throws Error if schema is invalid.
 */
export function validateArgsSchema(
  argsSchema: Record<string, ArgSchema> | null | undefined,
  blockName: string
): void {
  if (!argsSchema || typeof argsSchema !== "object") {
    return;
  }

  const groups = new Map<string, ArgUiGroup>();
  for (const [argName, argDef] of Object.entries(argsSchema)) {
    if (
      !validateArgName(argName, { entityName: blockName, entityType: "Block" })
    ) {
      continue;
    }

    const shouldContinue = validateArgSchemaEntry(argDef, argName, {
      entityName: blockName,
      entityType: "Block",
      validProperties: VALID_BLOCK_ARG_SCHEMA_PROPERTIES,
    });

    if (!shouldContinue) {
      continue;
    }

    validateBlockDefaultValue(argDef, argName, blockName);
    validateUIHints(argDef.ui, argName, blockName, "arg", argsSchema, groups);
  }
}

/**
 * Validates block arguments against the block's metadata arg schema.
 * Checks for required args and validates types.
 *
 * @param entry - The block entry.
 * @param blockClass - The resolved block class (must be a class, not a string reference).
 * @param options - Optional configuration.
 * @throws BlockError if args are invalid.
 */
export function validateBlockArgs(
  entry: Pick<LayoutEntry, "args">,
  blockClass: BlockClass,
  options: ValidateArgValueOptions = {}
): void {
  const metadata = getBlockMetadata(blockClass);
  const providedArgs = entry.args || {};
  const hasProvidedArgs = Object.keys(providedArgs).length > 0;
  const argsSchema = metadata?.args;

  // If args are provided but no schema exists, reject them
  if (hasProvidedArgs && !argsSchema) {
    const argNames = Object.keys(providedArgs).join(", ");
    throw new BlockError(
      `args were provided (${argNames}) but this block does not declare an args schema. ` +
        `Add an args schema to the @block decorator or remove the args.`,
      { path: "args" }
    );
  }

  // No schema and no args - nothing to validate
  if (!argsSchema) {
    return;
  }

  validateArgsAgainstSchema(providedArgs, argsSchema, "args", options);
}

/**
 * Validates the childArgs schema definition passed to the `@block` decorator.
 * Similar to validateArgsSchema but supports the additional "unique" property
 * for enforcing uniqueness across sibling children.
 *
 * @param childArgsSchema - The childArgs schema object from decorator options.
 * @param blockName - Block name for error messages.
 * @throws Error if schema is invalid.
 */
export function validateChildArgsSchema(
  childArgsSchema: Record<string, ChildArgSchema> | null | undefined,
  blockName: string,
  parentArgsSchema: Record<string, ArgSchema> = {}
): void {
  if (!childArgsSchema || typeof childArgsSchema !== "object") {
    return;
  }

  const groups = new Map<string, ArgUiGroup>();
  for (const [argName, argDef] of Object.entries(childArgsSchema)) {
    if (
      !validateArgName(argName, {
        entityName: blockName,
        entityType: "Block",
        argLabel: "childArgs arg",
      })
    ) {
      continue;
    }

    const shouldContinue = validateArgSchemaEntry(argDef, argName, {
      entityName: blockName,
      entityType: "Block",
      validProperties: VALID_CHILD_ARG_SCHEMA_PROPERTIES,
      argLabel: "childArgs arg",
    });

    if (!shouldContinue) {
      continue;
    }

    // childArgs-specific: validate "unique" is a boolean if provided
    if (argDef.unique !== undefined && typeof argDef.unique !== "boolean") {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has invalid "unique" value. Must be a boolean.`
      );
    }

    // childArgs-specific: validate "unique" is only used with primitive types
    if (argDef.unique === true && argDef.type === "array") {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has "unique: true" but type is "array". ` +
          `Uniqueness validation is only supported for primitive types (string, number, boolean).`
      );
    }

    validateBlockDefaultValue(argDef, argName, blockName, "childArgs arg");
    validateUIHints(
      argDef.ui,
      argName,
      blockName,
      "childArgs arg",
      parentArgsSchema,
      groups
    );
  }
}
