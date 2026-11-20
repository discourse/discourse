import guid from "pretty-text/guid";

/** Maps the type stored in a form definition to its registered FormKit renderer. */
const controlTypes = {
  text: "string",
  textarea: "textarea",
  number: "decimal",
  date: "date",
  checkbox: "bool",
  dropdown: "enum",
  radio: "radio-group",
} as const;

type FieldType = keyof typeof controlTypes;

/** Field and choice IDs remain stable across edits and reordering. */
interface Choice {
  id: string;
  label: string;
}

export interface Question extends Choice {
  type: FieldType;
  required: boolean;
  placeholder?: string;
  choices?: Choice[];
}

export interface FormDefinition {
  title: string;
  description?: string;
  fields: Question[];
}

export const fieldTypes = Object.keys(controlTypes) as FieldType[];
export const hasChoices = (type: FieldType) =>
  type === "dropdown" || type === "radio";
export const hasPlaceholder = (type: FieldType) =>
  ["text", "textarea", "number"].includes(type);

export function newChoice(): Choice {
  return { id: "f" + guid().replaceAll("-", ""), label: "" };
}

export function newQuestion(type: FieldType = "text"): Question {
  return {
    ...newChoice(),
    type,
    required: false,
    ...(hasChoices(type) && { choices: [newChoice()] }),
  };
}

/** Converts an authored question into the input accepted by SettingDefinitionField. */
export function settingDefinitionFor(field: Question) {
  return {
    key: field.id,
    label: field.label,
    type: controlTypes[field.type],
    placeholder: field.placeholder,
    required: field.required,
    valid_values: field.choices?.map(({ id, label }) => ({
      value: id,
      name: label,
    })),
    allows_none: !field.required,
  };
}
