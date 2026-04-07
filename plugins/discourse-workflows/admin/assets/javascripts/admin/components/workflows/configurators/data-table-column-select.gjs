import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import ComboBox from "discourse/select-kit/components/combo-box";
import { propertySelectNoneKey } from "../../../lib/workflows/property-engine";

export default class DataTableColumnSelect extends Component {
  get none() {
    return (
      this.args.schema?.ui?.none ||
      propertySelectNoneKey(this.args.nodeDefinition, this.args.fieldName)
    );
  }

  get options() {
    const id = parseInt(this.args.configuration?.data_table_id, 10);
    const dataTable =
      this.args.metadata?.data_tables?.find((dt) => dt.id === id) || null;

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
  </template>
}
