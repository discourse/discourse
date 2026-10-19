import { i18n } from "discourse-i18n";

export const WORKFLOW_VARIABLE_TYPE_VALUES = [
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

export function workflowVariableTypeLabel(variableType) {
  return i18n(`discourse_workflows.workflow_variables.types.${variableType}`);
}
