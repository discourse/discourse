import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import ParameterField from "./parameter-field";

const RESERVED_NAMES = ["created_at", "id", "updated_at"];

function sameFields(left = [], right = []) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function normalizeFields(fields = []) {
  return fields.map((field) => ({
    column: field.column,
    type: field.type,
    value: field.value ?? "",
  }));
}

export default class PropertyEngineDataTableFields extends Component {
  @tracked dataTable = null;
  @tracked fields = normalizeFields(this.args.value);
  #requestId = 0;

  get hasFields() {
    return this.fields.length > 0;
  }

  @action
  syncFromValue(_element, [value]) {
    if (this.dataTable) {
      return;
    }

    this.fields = normalizeFields(value);
  }

  @action
  async syncDataTable(_element, [rawDataTableId]) {
    const parsedId = parseInt(rawDataTableId, 10);

    if (!parsedId) {
      this.dataTable = null;
      this.fields = normalizeFields(this.args.value);
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
      this.#syncFieldsWithColumns();
    } catch {
      if (
        this.isDestroying ||
        this.isDestroyed ||
        requestId !== this.#requestId
      ) {
        return;
      }

      this.dataTable = null;
      this.fields = normalizeFields(this.args.value);
    }
  }

  @action
  updateFieldValue(index, value) {
    const fields = this.fields.map((field, fieldIndex) =>
      fieldIndex === index ? { ...field, value } : field
    );

    this.fields = fields;
    this.args.onPatch?.({ [this.args.fieldName]: fields });
  }

  #syncFieldsWithColumns() {
    if (!this.dataTable) {
      return;
    }

    const existingFields = normalizeFields(this.args.value);
    const fields = this.dataTable.columns
      .filter((column) => !RESERVED_NAMES.includes(column.name))
      .map((column) => {
        const existingField = existingFields.find(
          (field) => field.column === column.name
        );

        return {
          column: column.name,
          type: column.type,
          value: existingField?.value ?? "",
        };
      });

    this.fields = fields;

    if (!sameFields(fields, existingFields)) {
      this.args.onPatch?.({ [this.args.fieldName]: fields });
    }
  }

  <template>
    <div
      class="workflows-data-table-fields"
      {{didInsert this.syncDataTable @configuration.data_table_id}}
      {{didUpdate this.syncDataTable @configuration.data_table_id}}
      {{didUpdate this.syncFromValue @value}}
    >
      {{#if this.hasFields}}
        {{#each this.fields key="column" as |fieldItem index|}}
          <div class="workflows-data-table-fields__row">
            <span class="workflows-data-table-fields__column">
              <code>{{fieldItem.column}}</code>
              <span class="workflows-data-table-fields__type">
                {{fieldItem.type}}
              </span>
            </span>

            <ParameterField
              @value={{fieldItem.value}}
              @onChange={{fn this.updateFieldValue index}}
              as |value onInput|
            >
              <input
                type="text"
                value={{value}}
                placeholder={{i18n
                  "discourse_workflows.data_table_node.value_placeholder"
                }}
                {{on "input" onInput}}
              />
            </ParameterField>
          </div>
        {{/each}}
      {{/if}}
    </div>
  </template>
}
