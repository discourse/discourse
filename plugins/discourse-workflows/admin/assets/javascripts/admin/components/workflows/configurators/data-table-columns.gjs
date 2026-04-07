import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import Field from "./field";

function schemaForColumn(column) {
  switch (column.type) {
    case "number":
      return { type: "integer", name: column.name, ui: { expression: true } };
    case "boolean":
      return { type: "boolean", name: column.name, ui: { expression: true } };
    default:
      return { type: "string", name: column.name, ui: { expression: true } };
  }
}

export default class DataTableColumns extends Component {
  get columns() {
    const id = parseInt(this.args.configuration?.data_table_id, 10);
    const dataTable =
      this.args.metadata?.data_tables?.find((dt) => dt.id === id) || null;

    return dataTable?.columns ?? [];
  }

  get columnsConfiguration() {
    return this.args.configuration?.[this.args.fieldName] || {};
  }

  <template>
    {{#if this.columns.length}}
      <@form.Object @name={{@fieldName}} as |object|>
        {{#each this.columns key="name" as |column|}}
          <Field
            @form={{object}}
            @formApi={{@formApi}}
            @fieldName={{column.name}}
            @formApiPath={{concat @fieldName "." column.name}}
            @configuration={{this.columnsConfiguration}}
            @label={{column.name}}
            @schema={{schemaForColumn column}}
          />
        {{/each}}
      </@form.Object>
    {{/if}}
  </template>
}
