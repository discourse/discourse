import { i18n } from "discourse-i18n";

export const SETTING_FIELD_TYPE_VALUES = [
  "string",
  "integer",
  "boolean",
  "enum",
  "category",
  "category_list",
  "group",
  "group_list",
  "tag_list",
  "simple_list",
];

export function settingFieldTypeLabel(fieldType) {
  return i18n(`discourse_workflows.settings.fields.field_types.${fieldType}`);
}
