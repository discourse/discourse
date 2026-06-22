import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";
import { propertySelectNoneKey } from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

export default class DataTableColumnSelect extends Component {
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

  get none() {
    return (
      this.args.schema?.ui?.none ||
      propertySelectNoneKey(this.args.nodeDefinition, this.args.fieldName)
    );
  }

  get options() {
    const id = parseInt(this.args.configuration?.data_table_id, 10);
    const dataTables =
      this.args.metadata?.data_tables || this._loadedDataTables || [];
    const dataTable = dataTables.find((dt) => dt.id === id) || null;

    return (
      dataTable?.columns?.map((column) => ({
        id: column.name,
        name: column.name,
      })) ?? []
    );
  }

  @action
  handleChange(value) {
    this.args.field.set(value || "");
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @schema={{@schema}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      {{#if this.options.length}}
        <ComboBox
          class="workflows-data-table-column-select"
          @content={{this.options}}
          @nameProperty="name"
          @value={{@field.value}}
          @valueProperty="id"
          @onChange={{this.handleChange}}
          @options={{hash none=this.none}}
        />
      {{/if}}
    </ExpressionWrapper>
  </template>
}
