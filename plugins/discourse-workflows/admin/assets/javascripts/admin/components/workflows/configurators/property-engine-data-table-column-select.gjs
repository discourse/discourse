import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { ajax } from "discourse/lib/ajax";
import ComboBox from "discourse/select-kit/components/combo-box";
import { propertySelectNoneKey } from "../../../lib/workflows/property-engine";

export default class PropertyEngineDataTableColumnSelect extends Component {
  @tracked dataTable = null;
  #requestId = 0;

  get none() {
    return (
      this.args.schema?.ui?.none ||
      propertySelectNoneKey(this.args.nodeDefinition, this.args.fieldName)
    );
  }

  get options() {
    return (
      this.dataTable?.columns?.map((column) => ({
        id: String(column.id),
        name: column.name,
      })) ?? []
    );
  }

  @action
  async syncDataTable(_element, [rawDataTableId]) {
    const parsedId = parseInt(rawDataTableId, 10);

    if (!parsedId) {
      this.dataTable = null;
      return;
    }

    if (this.dataTable?.id === parsedId) {
      return;
    }

    const requestId = ++this.#requestId;

    try {
      const result = await ajax(
        `/admin/plugins/discourse-workflows/data-tables/${parsedId}.json`
      );

      if (
        this.isDestroying ||
        this.isDestroyed ||
        requestId !== this.#requestId
      ) {
        return;
      }

      this.dataTable = result.data_table;
    } catch {
      if (
        this.isDestroying ||
        this.isDestroyed ||
        requestId !== this.#requestId
      ) {
        return;
      }

      this.dataTable = null;
    }
  }

  @action
  handleChange(value) {
    this.args.onPatch?.({ [this.args.fieldName]: value || "" });
  }

  <template>
    <div
      {{didInsert this.syncDataTable @configuration.data_table_id}}
      {{didUpdate this.syncDataTable @configuration.data_table_id}}
    >
      {{#if this.dataTable}}
        <ComboBox
          @content={{this.options}}
          @nameProperty="name"
          @value={{@value}}
          @valueProperty="id"
          @onChange={{this.handleChange}}
          @options={{hash none=this.none}}
        />
      {{/if}}
    </div>
  </template>
}
