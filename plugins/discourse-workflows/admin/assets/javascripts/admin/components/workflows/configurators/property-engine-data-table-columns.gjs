import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { ajax } from "discourse/lib/ajax";
import PropertyEngineField from "./property-engine-field";

const RESERVED_NAMES = ["created_at", "id", "updated_at"];

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

export default class PropertyEngineDataTableColumns extends Component {
  @tracked dataTable = null;
  #requestId = 0;

  get columns() {
    return (
      this.dataTable?.columns?.filter(
        (c) => !RESERVED_NAMES.includes(c.name)
      ) ?? []
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
      if (!this.args.formApi?.get(this.args.fieldName)) {
        this.args.formApi?.set(this.args.fieldName, {});
      }
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

  <template>
    <div
      {{didInsert this.syncDataTable @configuration.data_table_id}}
      {{didUpdate this.syncDataTable @configuration.data_table_id}}
    >
      {{#if this.dataTable}}
        <@form.Object @name={{@fieldName}} as |object|>
          {{#each this.columns key="id" as |column|}}
            <PropertyEngineField
              @form={{object}}
              @formApi={{@formApi}}
              @fieldName={{column.id}}
              @formApiPath={{concat @fieldName "." column.id}}
              @label={{column.name}}
              @schema={{schemaForColumn column}}
            />
          {{/each}}
        </@form.Object>
      {{/if}}
    </div>
  </template>
}
