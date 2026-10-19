import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import {
  isKeyedValue,
  keyedValue,
  withoutKey,
} from "../../../lib/workflows/keyed-collection.js";
import {
  isExpression,
  usesInlineBooleanControl,
} from "../../../lib/workflows/property-engine.js";
import CollectionAddMenu from "./collection-add-menu.gjs";
import CollectionOptionRow from "./collection-option-row.gjs";
import Field from "./field.gjs";

const COLUMN_FIELD_TYPES = { number: "integer", boolean: "boolean" };

function schemaForColumn(column) {
  return {
    type: COLUMN_FIELD_TYPES[column.type] ?? "string",
    name: column.name,
    ui: { expression: true },
    validate: "non_empty_expression",
  };
}

export default class DataTableColumns extends Component {
  @service workflowsNodeTypes;

  // Keeps each column's schema stable across edits so its Field isn't rebuilt
  // on every keystroke.
  #schemas = new Map();
  @tracked _loadedDataTables = null;

  @tracked _loading = false;

  constructor(owner, args) {
    super(owner, args);
    const identifier =
      args.nodeDefinition?.name || args.nodeDefinition?.identifier;
    if (identifier && !args.metadata?.data_tables) {
      const context = {
        path: "data_table_id",
        currentNodeParameters: args.configuration || {},
      };
      this._loading = true;
      this.workflowsNodeTypes
        .loadNodeParameterOptions(
          identifier,
          "data_tables",
          args.nodeDefinition?.version,
          args.session?.nodeParameterOptionsContext(context) || context
        )
        .then((dataTables) => {
          this._loadedDataTables = dataTables;
        })
        .finally(() => {
          this._loading = false;
        });
    }
  }

  @cached
  get dataTable() {
    const id = parseInt(this.args.configuration?.data_table_id, 10);
    const dataTables =
      this.args.metadata?.data_tables || this._loadedDataTables || [];

    return dataTables.find((dt) => dt.id === id) || null;
  }

  @cached
  get columns() {
    return (this.dataTable?.columns ?? []).filter((c) => !c.reserved);
  }

  get rawValue() {
    return this.args.formApi?.get(this.args.fieldName);
  }

  get currentValue() {
    return keyedValue(this.rawValue);
  }

  // Keys stay visible while the table is unresolved so they can still be
  // edited or removed. A whole-object expression is left untouched.
  get showColumns() {
    if (this._loading) {
      return false;
    }
    if (this.rawValue != null && !isKeyedValue(this.rawValue)) {
      return false;
    }
    return Boolean(this.dataTable) || this.rows.length > 0;
  }

  @cached
  get rows() {
    const names = new Set(this.columns.map((column) => column.name));
    const known = this.columns
      .filter((column) => Object.hasOwn(this.currentValue, column.name))
      .map((column) => ({
        name: column.name,
        schema: this.#schemaFor(column),
      }));
    // Only a resolved table can prove a column is gone; an expression id or an
    // unloaded table can't, so those keys stay editable as plain columns.
    const unknown = Object.keys(this.currentValue)
      .filter((name) => !names.has(name))
      .map((name) =>
        this.dataTable
          ? { name, missing: true }
          : { name, schema: this.#schemaFor({ name }) }
      );

    return [...known, ...unknown];
  }

  @cached
  get availableColumns() {
    return this.columns.filter(
      (column) => !Object.hasOwn(this.currentValue, column.name)
    );
  }

  @action
  usesInlineControl(row) {
    return (
      !row.missing &&
      usesInlineBooleanControl(row.schema, this.currentValue[row.name])
    );
  }

  // An empty expression is an error, not NULL, so the hint only fits Plain
  // mode. "" rather than undefined stops Field falling back to a shared one.
  @action
  placeholderFor(name) {
    if (isExpression(this.currentValue[name])) {
      return "";
    }
    return i18n("discourse_workflows.data_table_node.empty_column_placeholder");
  }

  // Switching an empty expression back to Plain yields "", which looks like the
  // NULL placeholder but would write an empty string.
  @action
  setColumnValue(value, { set, name }) {
    set(name, value === "" ? null : value);
  }

  @action
  addColumn(column, close) {
    this.#addColumns([column]);
    close?.();
  }

  @action
  addAllColumns(close) {
    this.#addColumns(this.availableColumns);
    close?.();
  }

  @action
  removeColumn(name) {
    this.args.formApi.set(
      this.args.fieldName,
      withoutKey(this.currentValue, name)
    );
  }

  #schemaFor(column) {
    const key = `${column.type}:${column.name}`;
    if (!this.#schemas.has(key)) {
      this.#schemas.set(key, schemaForColumn(column));
    }
    return this.#schemas.get(key);
  }

  // Booleans start as false because the toggle can't show NULL.
  #addColumns(columns) {
    const added = Object.fromEntries(
      columns.map((column) => [
        column.name,
        column.type === "boolean" ? false : null,
      ])
    );
    this.args.formApi.set(this.args.fieldName, {
      ...this.currentValue,
      ...added,
    });
  }

  <template>
    {{#if this.showColumns}}
      <@form.Section class="workflows-data-table-columns" @title={{@label}}>
        <@form.Object @name={{@fieldName}} as |object item|>
          {{#each this.rows key="name" as |row|}}
            <CollectionOptionRow
              class={{dConcatClass
                "workflows-data-table-columns__column"
                (if row.missing "--missing")
              }}
              data-column-name={{row.name}}
              @inlineControl={{this.usesInlineControl row}}
              @onRemove={{fn this.removeColumn row.name}}
              @removeLabel={{i18n
                "discourse_workflows.property_engine.remove_assignment"
                name=row.name
              }}
            >
              {{#if row.missing}}
                <@form.Alert
                  class="workflows-data-table-columns__missing"
                  @type="error"
                >
                  {{i18n
                    "discourse_workflows.data_table_node.missing_column"
                    name=row.name
                  }}
                </@form.Alert>
              {{else}}
                <Field
                  @configuration={{item}}
                  @fieldName={{row.name}}
                  @form={{object}}
                  @formApi={{@formApi}}
                  @label={{row.name}}
                  @onSet={{this.setColumnValue}}
                  @placeholder={{this.placeholderFor row.name}}
                  @schema={{row.schema}}
                  @session={{@session}}
                  @showOptional={{false}}
                />
              {{/if}}
            </CollectionOptionRow>
          {{/each}}
        </@form.Object>

        {{#if this.availableColumns.length}}
          <CollectionAddMenu
            @addAllLabel={{i18n
              "discourse_workflows.data_table_node.add_all_columns"
            }}
            @label={{i18n "discourse_workflows.data_table_node.add_column"}}
            @onAdd={{this.addColumn}}
            @onAddAll={{this.addAllColumns}}
            @options={{this.availableColumns}}
          />
        {{/if}}
      </@form.Section>
    {{/if}}
  </template>
}
