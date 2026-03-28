import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import { resolvePreviousOutput } from "../context/input";
import WorkflowsEmptyState from "../empty-state";
import PropertyEngineField from "./property-engine-field";

const OPERATORS_BY_TYPE = {
  string: [
    "equals",
    "notEquals",
    "contains",
    "notContains",
    "empty",
    "notEmpty",
  ],
  number: ["equals", "notEquals", "gt", "lt", "gte", "lte"],
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

function isExpression(value) {
  return typeof value === "string" && value.startsWith("=");
}

function leftValueSchema(fieldOptions) {
  return {
    type: "options",
    required: true,
    options: fieldOptions.map((f) => ({ value: f.id, label: f.label })),
    ui: { expression: true },
  };
}

function operationSchema(item) {
  const type = item?.operator?.type || "string";
  return {
    type: "options",
    required: true,
    options: operatorsForType(type),
    ui: { expression: true },
  };
}

const CATEGORY_FIELDS = ["category_id", "category"];
const USER_FIELDS = ["username"];

function rightValueSchema(item) {
  const leftValue = item?.leftValue;

  if (CATEGORY_FIELDS.includes(leftValue)) {
    return {
      type: "string",
      required: true,
      ui: { expression: true, control: "category" },
    };
  }

  if (USER_FIELDS.includes(leftValue)) {
    return {
      type: "string",
      required: true,
      ui: { expression: true, control: "user" },
    };
  }

  return {
    type: "string",
    required: true,
    ui: { expression: true },
  };
}

export default class PropertyEngineConditionBuilder extends Component {
  get conditions() {
    return this.args.formApi?.get(this.args.fieldName) || [];
  }

  get fieldOptions() {
    const fields = resolvePreviousOutput(
      this.args.node,
      this.args.nodes || [],
      this.args.connections || [],
      this.args.nodeTypes || []
    );

    return fields.map((field) => ({
      id: field.key,
      label: field.key,
      type: field.type,
    }));
  }

  @action
  addCondition() {
    const conditions = this.conditions;
    this.args.formApi.set(this.args.fieldName, [
      ...conditions,
      {
        id: crypto.randomUUID(),
        leftValue: "",
        operator: {
          operation: "equals",
          singleValue: false,
          type: "string",
        },
        rightValue: "",
      },
    ]);
  }

  @action
  handleLeftValueSet(index, value, { set, name }) {
    set(name, value);

    if (isExpression(value)) {
      return;
    }

    const field = this.fieldOptions.find((option) => option.id === value);
    const type = field?.type || "string";
    const operation = operatorsForType(type)[0];
    const basePath = `${this.args.fieldName}.${index}`;

    this.args.formApi.set(`${basePath}.operator`, {
      operation,
      type,
      singleValue: singleValueOperator(operation),
    });
    this.args.formApi.set(`${basePath}.rightValue`, "");
  }

  @action
  handleOperatorSet(index, value, { set, name }) {
    set(name, value);

    if (isExpression(value)) {
      return;
    }

    this.args.formApi.set(
      `${this.args.fieldName}.${index}.operator.singleValue`,
      singleValueOperator(value)
    );
  }

  <template>
    <@form.Collection
      @name={{@fieldName}}
      @tagName="div"
      class="workflows-configurator-if"
      as |collection index item|
    >
      <div class="workflows-configurator-if__row">
        <div class="workflows-configurator-if__delete">
          <DButton
            @action={{fn collection.remove index}}
            @icon="trash-can"
            class="btn-transparent btn-small btn-danger"
          />
        </div>

        <collection.Object
          class="workflows-configurator-if__fields"
          as |object|
        >
          <PropertyEngineField
            @form={{object}}
            @formApi={{@formApi}}
            @fieldName="leftValue"
            @formApiPath={{concat @fieldName "." index ".leftValue"}}
            @schema={{leftValueSchema this.fieldOptions}}
            @label={{i18n "discourse_workflows.if_condition.field"}}
            @onSet={{fn this.handleLeftValueSet index}}
          />

          <object.Object @name="operator" as |operator|>
            <PropertyEngineField
              @form={{operator}}
              @formApi={{@formApi}}
              @fieldName="operation"
              @formApiPath={{concat @fieldName "." index ".operator.operation"}}
              @schema={{operationSchema item}}
              @label={{i18n "discourse_workflows.if_condition.operator"}}
              @onSet={{fn this.handleOperatorSet index}}
            />
          </object.Object>

          {{#unless (isSingleValueItem item)}}
            <PropertyEngineField
              @form={{object}}
              @formApi={{@formApi}}
              @fieldName="rightValue"
              @formApiPath={{concat @fieldName "." index ".rightValue"}}
              @schema={{rightValueSchema item}}
              @label={{i18n "discourse_workflows.if_condition.value"}}
            />
          {{/unless}}
        </collection.Object>
      </div>
    </@form.Collection>

    {{#if this.conditions.length}}
      <DButton
        @action={{this.addCondition}}
        @icon="plus"
        @label="discourse_workflows.if_condition.add_condition"
        class="btn-default btn-small"
      />
    {{else}}
      <WorkflowsEmptyState
        @description={{i18n
          "discourse_workflows.if_condition.no_conditions_body"
        }}
        @onAction={{this.addCondition}}
        @buttonIcon="plus"
        @buttonLabel="discourse_workflows.if_condition.add_condition"
      />
    {{/if}}
  </template>
}
