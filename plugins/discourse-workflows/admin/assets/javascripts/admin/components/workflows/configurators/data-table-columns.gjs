import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
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
  @service workflowsNodeTypes;

  @tracked _loadedDataTables = null;

  constructor(owner, args) {
    super(owner, args);
    const identifier =
      args.nodeDefinition?.name || args.nodeDefinition?.identifier;
    if (identifier) {
      this.workflowsNodeTypes
        .loadNodeParameterOptions(
          identifier,
          "data_tables",
          args.nodeDefinition?.version,
          args.session?.nodeParameterOptionsContext({
            path: "data_table_id",
            currentNodeParameters: args.configuration || {},
          }) || {
            path: "data_table_id",
            currentNodeParameters: args.configuration || {},
          }
        )
        .then((dataTables) => {
          this._loadedDataTables = dataTables;
        });
    }
  }

  get columns() {
    const id = parseInt(this.args.configuration?.data_table_id, 10);
    const dataTables =
      this.args.metadata?.data_tables || this._loadedDataTables || [];
    const dataTable = dataTables.find((dt) => dt.id === id) || null;

    return (dataTable?.columns ?? []).filter((c) => !c.reserved);
  }

  get columnsConfiguration() {
    return this.args.configuration?.[this.args.fieldName] || {};
  }

  <template>
    {{#if this.columns.length}}
      <@form.Section @title={{@label}}>
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
              @session={{@session}}
            />
          {{/each}}
        </@form.Object>
      </@form.Section>
    {{/if}}
  </template>
}
