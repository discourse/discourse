import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import ConditionBuilder from "./condition-builder";

function columnTypeToFieldType(columnType) {
  switch (columnType) {
    case "number":
      return "number";
    case "boolean":
      return "boolean";
    default:
      return "string";
  }
}

export default class DataTableConditionBuilder extends Component {
  get dataTable() {
    const id = parseInt(this.args.dataTableId, 10);
    return this.args.metadata?.data_tables?.find((dt) => dt.id === id) || null;
  }

  get fieldOptions() {
    return (this.dataTable?.columns ?? []).map((column) => ({
      id: column.name,
      label: `${column.name} (${column.type})`,
      type: columnTypeToFieldType(column.type),
    }));
  }

  <template>
    {{#if this.dataTable}}
      <ConditionBuilder
        @form={{@form}}
        @formApi={{@formApi}}
        @fieldName={{@fieldName}}
        @label={{@label}}
        @fieldOptions={{this.fieldOptions}}
        @fieldLabel={{i18n "discourse_workflows.if.column"}}
      />
    {{/if}}
  </template>
}
