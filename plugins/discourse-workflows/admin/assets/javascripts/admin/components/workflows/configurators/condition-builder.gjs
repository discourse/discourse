import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import { resolvePreviousOutput } from "../../../lib/workflows/graph-traversal";
import { isExpression } from "../../../lib/workflows/property-engine";
import Collection from "./collection";
import Field from "./field";

function flattenFields(fields, prefix = "") {
  const result = [];
  for (const field of fields) {
    const path = prefix ? `${prefix}.${field.key}` : field.key;
    if (field.children?.length) {
      result.push(...flattenFields(field.children, path));
    } else {
      result.push({ id: path, label: path, type: field.type });
    }
  }
  return result;
}

const OPERATORS_BY_TYPE = {
  string: [
    "equals",
    "notEquals",
    "contains",
    "notContains",
    "empty",
    "notEmpty",
  ],
  integer: ["equals", "notEquals", "gt", "lt", "gte", "lte"],
  boolean: ["true", "false", "equals", "notEquals"],
  array: ["contains", "notContains", "empty", "notEmpty"],
};

const SINGLE_VALUE_OPERATORS = ["empty", "notEmpty", "true", "false"];

function operatorsForType(type) {
  return OPERATORS_BY_TYPE[type] || OPERATORS_BY_TYPE.string;
}

function singleValueOperator(operation) {
  return SINGLE_VALUE_OPERATORS.includes(operation);
}

function isSingleValueItem(item) {
  return singleValueOperator(item?.operator?.operation);
}

const CATEGORY_FIELDS = ["category_id", "category"];
const USER_FIELDS = ["username"];

function leafKey(fieldPath) {
  if (!fieldPath) {
    return fieldPath;
  }

  let path = fieldPath;
  const exprMatch = path.match(/^=\{\{\s*\$json\.(.*?)\s*\}\}$/);
  if (exprMatch) {
    path = exprMatch[1];
  }

  const parts = path.split(".");
  return parts[parts.length - 1];
}

const RIGHT_VALUE_SCHEMAS = {
  category: {
    type: "string",
    required: true,
    ui: { expression: true, control: "category" },
  },
  user: {
    type: "string",
    required: true,
    ui: { expression: true, control: "user" },
  },
  default: {
    type: "string",
    required: true,
    ui: { expression: true },
  },
};

function rightValueSchema(item) {
  const leaf = leafKey(item?.leftValue);

  if (CATEGORY_FIELDS.includes(leaf)) {
    return RIGHT_VALUE_SCHEMAS.category;
  }

  if (USER_FIELDS.includes(leaf)) {
    return RIGHT_VALUE_SCHEMAS.user;
  }

  return RIGHT_VALUE_SCHEMAS.default;
}

function leftValueSchema(fieldOptions) {
  return {
    type: "options",
    required: true,
    options: fieldOptions.map((f) => ({ value: f.id, label: f.label })),
    ui: { expression: true },
  };
}

const OPERATION_SCHEMAS = {};

function operationSchema(item) {
  const type = item?.operator?.type || "string";
  return (OPERATION_SCHEMAS[type] ??= {
    type: "options",
    required: true,
    options: operatorsForType(type),
    ui: { expression: true },
  });
}

export default class ConditionBuilder extends Component {
  @tracked _conditionSchemas = (
    this.args.formApi?.get(this.args.fieldName) || []
  ).map((item) => this.#buildConditionSchema(item));

  #buildConditionSchema(item) {
    return {
      opSchema: operationSchema(item),
      singleValue: isSingleValueItem(item),
      rvSchema: rightValueSchema(item),
    };
  }

  #updateSchemaAtIndex(index, schema) {
    const newSchemas = [...this._conditionSchemas];
    newSchemas[index] = schema;
    this._conditionSchemas = newSchemas;
  }

  get fieldOptions() {
    if (this.args.fieldOptions) {
      return this.args.fieldOptions;
    }

    const fields = resolvePreviousOutput(this.args.node, {
      nodes: this.args.nodes || [],
      connections: this.args.connections || [],
      nodeTypes: this.args.nodeTypes || [],
    });

    return flattenFields(fields);
  }

  get fieldLabel() {
    return this.args.fieldLabel || i18n("discourse_workflows.if.field");
  }

  @action
  emptyCondition() {
    return {
      id: crypto.randomUUID(),
      leftValue: "",
      operator: {
        operation: "equals",
        singleValue: false,
        type: "string",
      },
      rightValue: "",
    };
  }

  @action
  onConditionAdded(item) {
    this._conditionSchemas = [
      ...this._conditionSchemas,
      this.#buildConditionSchema(item),
    ];
  }

  @action
  removeCondition(index) {
    const newSchemas = [...this._conditionSchemas];
    newSchemas.splice(index, 1);
    this._conditionSchemas = newSchemas;
  }

  @action
  handleLeftValueSet(index, value, { set, name }) {
    if (isExpression(value)) {
      set(name, value);
      return;
    }

    const field = this.fieldOptions.find((option) => option.id === value);
    const type = field?.type || "string";

    const storedValue = this.args.fieldOptions
      ? value
      : `={{ $json.${value} }}`;
    set(name, storedValue);

    const operation = operatorsForType(type)[0];
    const basePath = `${this.args.fieldName}.${index}`;

    set(`${basePath}.operator`, {
      operation,
      type,
      singleValue: singleValueOperator(operation),
    });
    set(`${basePath}.rightValue`, "");

    const data = this.args.formApi.get(basePath);
    this.#updateSchemaAtIndex(index, this.#buildConditionSchema(data));
  }

  @action
  handleOperatorSet(index, value, { set, name }) {
    set(name, value);

    if (isExpression(value)) {
      return;
    }

    set(
      `${this.args.fieldName}.${index}.operator.singleValue`,
      singleValueOperator(value)
    );

    this.#updateSchemaAtIndex(index, {
      ...this._conditionSchemas[index],
      singleValue: singleValueOperator(value),
    });
  }

  <template>
    <Collection
      @form={{@form}}
      @formApi={{@formApi}}
      @fieldName={{@fieldName}}
      @label={{@label}}
      @addLabel={{i18n "discourse_workflows.if.add_condition"}}
      @emptyItem={{this.emptyCondition}}
      @onAdd={{this.onConditionAdded}}
      @onRemove={{this.removeCondition}}
      @emptyStateDescription={{i18n
        "discourse_workflows.if.no_conditions_body"
      }}
      as |ctx|
    >
      <Field
        @form={{ctx.object}}
        @formApi={{@formApi}}
        @configuration={{ctx.item}}
        @fieldName="leftValue"
        @schema={{leftValueSchema this.fieldOptions}}
        @label={{this.fieldLabel}}
        @onSet={{fn this.handleLeftValueSet ctx.index}}
      />

      {{#let (get this._conditionSchemas ctx.index) as |schemas|}}
        <ctx.object.Object @name="operator" as |operator|>
          <Field
            @form={{operator}}
            @formApi={{@formApi}}
            @configuration={{ctx.item.operator}}
            @fieldName="operation"
            @schema={{schemas.opSchema}}
            @label={{i18n "discourse_workflows.if.operator"}}
            @onSet={{fn this.handleOperatorSet ctx.index}}
          />
        </ctx.object.Object>

        {{#unless schemas.singleValue}}
          <Field
            @form={{ctx.object}}
            @formApi={{@formApi}}
            @configuration={{ctx.item}}
            @fieldName="rightValue"
            @schema={{schemas.rvSchema}}
            @label={{i18n "discourse_workflows.if.value"}}
          />
        {{/unless}}
      {{/let}}
    </Collection>
  </template>
}
