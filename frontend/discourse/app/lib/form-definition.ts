import guid from "pretty-text/guid";
import { i18n } from "discourse-i18n";

/** Maps the type stored in a form definition to its registered FormKit renderer. */
const controlTypes = {
  text: "string",
  textarea: "textarea",
  number: "decimal",
  date: "date",
  checkbox: "bool",
  radio: "radio-group",
  dropdown: "enum",
  checkboxes: "checkbox-group",
} as const;

type QuestionType = keyof typeof controlTypes;
type FieldType = QuestionType | "display_text";

/** Field and choice IDs remain stable across edits and reordering. */
interface Choice {
  id: string;
  label: string;
}

export interface Question extends Choice {
  type: QuestionType;
  required: boolean;
  description?: string;
  placeholder?: string;
  choices?: Choice[];
}

interface DisplayText {
  id: string;
  type: "display_text";
  content: string;
}

export interface FormDefinition {
  title: string;
  description?: string;
  fields: (Question | DisplayText)[];
}

export const fieldTypes: FieldType[] = [
  ...(Object.keys(controlTypes) as QuestionType[]),
  "display_text",
];
export const hasChoices = (type: FieldType) =>
  type === "radio" || type === "dropdown" || type === "checkboxes";
export const hasPlaceholder = (type: FieldType) =>
  ["text", "textarea", "number"].includes(type);

export function newChoice(): Choice {
  return { id: "f" + guid().replaceAll("-", ""), label: "" };
}

export function initialChoices(): Choice[] {
  return [newChoice(), newChoice()];
}

export function newQuestion(type: QuestionType = "text"): Question {
  return {
    ...newChoice(),
    type,
    required: false,
    ...(hasChoices(type) && { choices: initialChoices() }),
  };
}

/** Creates a blank node for the first type offered by the editor. */
export function newFormField(type: FieldType = "text"): Question | DisplayText {
  if (type === "display_text") {
    return { id: newChoice().id, type, content: "" };
  }
  return newQuestion(type);
}

/** Converts an authored question into the input accepted by SettingDefinitionField. */
export function settingDefinitionFor(field: Question) {
  return {
    key: field.id,
    label: field.label?.trim() ? field.label : i18n("form_definition.untitled"),
    type: controlTypes[field.type],
    help_text: field.description,
    placeholder: field.placeholder,
    required: field.required,
    valid_values: field.choices?.map(({ id, label }, index) => ({
      value: id,
      name: label?.trim()
        ? label
        : i18n("form_definition.choice_number", { number: index + 1 }),
    })),
    allows_none: !field.required,
  };
}
