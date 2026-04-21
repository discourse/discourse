import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import {
  implicitValueFor,
  isSingleValueOperator,
  operatorsForType,
} from "../../../lib/workflows/condition-operators";
import Collection from "./collection";
import Field from "./field";

const VALUE_SCHEMA = { type: "string", required: true };

function columnTypeToFieldType(columnType) {
  switch (columnType) {
    case "number":
      return "integer";
    case "boolean":
      return "boolean";
    default:
      return "string";
  }
}

function conditionSchema(type) {
  return {
    type: "options",
    required: true,
    options: operatorsForType(type),
  };
}

export default class DataTableConditionBuilder extends Component {
  @tracked schemas = this.#initSchemas();

  get dataTable() {
    const id = parseInt(this.args.configuration?.data_table_id, 10);
    return this.args.metadata?.data_tables?.find((dt) => dt.id === id) || null;
  }

  get fieldOptions() {
    return (this.dataTable?.columns ?? []).map((column) => ({
      id: column.name,
      label: `${column.name} (${column.type})`,
      type: columnTypeToFieldType(column.type),
    }));
  }

  get columnSchema() {
    return {
      type: "options",
      required: true,
      options: this.fieldOptions.map((f) => ({ value: f.id, label: f.label })),
    };
  }

  #fieldTypeForColumn(columnName) {
    const field = this.fieldOptions.find((f) => f.id === columnName);
    return field?.type || "string";
  }

  #initSchemas() {
    const items = this.args.formApi?.get(this.args.fieldName) || [];
    return items.map((item) => this.#buildSchema(item));
  }

  #buildSchema(item) {
    const fieldType = this.#fieldTypeForColumn(item?.columnName);
    return {
      conditionSchema: conditionSchema(fieldType),
      singleValue: isSingleValueOperator(item?.condition),
    };
  }

  #updateSchemaAt(index, schema) {
    const updated = [...this.schemas];
    updated[index] = schema;
    this.schemas = updated;
  }

  @action
  emptyItem() {
    return { columnName: "", condition: "equals", value: "" };
  }

  @action
  onItemAdded(item) {
    this.schemas = [...this.schemas, this.#buildSchema(item)];
  }

  @action
  onItemRemoved(index) {
    const updated = [...this.schemas];
    updated.splice(index, 1);
    this.schemas = updated;
  }

  @action
  handleColumnChange(index, value, { set, name }) {
    set(name, value);

    const fieldType = this.#fieldTypeForColumn(value);
    const defaultOp = operatorsForType(fieldType)[0];
    const basePath = `${this.args.fieldName}.${index}`;

    set(`${basePath}.condition`, defaultOp);
    set(`${basePath}.value`, isSingleValueOperator(defaultOp) ? null : "");

    this.#updateSchemaAt(index, {
      conditionSchema: conditionSchema(fieldType),
      singleValue: isSingleValueOperator(defaultOp),
    });
  }

  @action
  handleConditionChange(index, value, { set, name }) {
    set(name, value);

    if (isSingleValueOperator(value)) {
      set(`${this.args.fieldName}.${index}.value`, implicitValueFor(value));
    }

    this.#updateSchemaAt(index, {
      ...this.schemas[index],
      singleValue: isSingleValueOperator(value),
    });
  }

  <template>
    {{#if this.dataTable}}
      <Collection
        @form={{@form}}
        @formApi={{@formApi}}
        @fieldName={{@fieldName}}
        @label={{@label}}
        @addLabel={{i18n "discourse_workflows.if.add_condition"}}
        @emptyItem={{this.emptyItem}}
        @onAdd={{this.onItemAdded}}
        @onRemove={{this.onItemRemoved}}
        @emptyStateDescription={{i18n
          "discourse_workflows.if.no_conditions_body"
        }}
        as |ctx|
      >
        <Field
          @form={{ctx.object}}
          @formApi={{@formApi}}
          @configuration={{ctx.item}}
          @fieldName="columnName"
          @schema={{this.columnSchema}}
          @label={{i18n "discourse_workflows.if.column"}}
          @onSet={{fn this.handleColumnChange ctx.index}}
        />

        {{#let (get this.schemas ctx.index) as |schemas|}}
          {{#if schemas}}
            <Field
              @form={{ctx.object}}
              @formApi={{@formApi}}
              @configuration={{ctx.item}}
              @fieldName="condition"
              @schema={{schemas.conditionSchema}}
              @label={{i18n "discourse_workflows.if.operator"}}
              @onSet={{fn this.handleConditionChange ctx.index}}
            />

            {{#unless schemas.singleValue}}
              <Field
                @form={{ctx.object}}
                @formApi={{@formApi}}
                @configuration={{ctx.item}}
                @fieldName="value"
                @schema={{VALUE_SCHEMA}}
                @label={{i18n "discourse_workflows.if.value"}}
              />
            {{/unless}}
          {{/if}}
        {{/let}}
      </Collection>
    {{/if}}
  </template>
}
