import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { resolvePreviousOutput } from "../context/input";
import ParameterField from "./parameter-field";

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

function conditionRows(conditions) {
  return (conditions || []).map((condition, index) => {
    const operatorType = condition.operator?.type || "string";
    const operation =
      condition.operator?.operation || operatorsForType(operatorType)[0];

    return {
      condition,
      index,
      isSingleValue: singleValueOperator(operation),
      operators: operatorsForType(operatorType),
      operation,
    };
  });
}

export default class PropertyEngineConditionBuilder extends Component {
  get conditions() {
    return this.args.value || [];
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

  get rows() {
    return conditionRows(this.conditions);
  }

  #patchConditions(conditions) {
    this.args.onPatch?.({ [this.args.fieldName]: conditions });
  }

  @action
  addCondition() {
    this.#patchConditions([
      ...this.conditions,
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
  removeCondition(index) {
    this.#patchConditions(
      this.conditions.filter((_, conditionIndex) => conditionIndex !== index)
    );
  }

  @action
  updateConditionField(index, event) {
    const fieldId = event.target.value;
    const field = this.fieldOptions.find((option) => option.id === fieldId);
    const type = field?.type || "string";
    const operation = operatorsForType(type)[0];

    this.#updateCondition(index, {
      leftValue: fieldId,
      operator: {
        operation,
        singleValue: singleValueOperator(operation),
        type,
      },
      rightValue: "",
    });
  }

  @action
  updateConditionLeftExpression(index, value) {
    this.#updateCondition(index, { leftValue: value });
  }

  @action
  updateConditionOperator(index, event) {
    const operation = event.target.value;
    const currentCondition = this.conditions[index] || {};

    this.#updateCondition(index, {
      operator: {
        ...(currentCondition.operator || {}),
        operation,
        singleValue: singleValueOperator(operation),
      },
    });
  }

  @action
  updateConditionValue(index, value) {
    this.#updateCondition(index, { rightValue: value });
  }

  #updateCondition(index, updates) {
    this.#patchConditions(
      this.conditions.map((condition, conditionIndex) =>
        conditionIndex === index
          ? {
              ...condition,
              ...updates,
              operator: {
                ...(condition.operator || {}),
                ...(updates.operator || {}),
              },
            }
          : condition
      )
    );
  }

  <template>
    <div class="workflows-configurator-if">
      {{#each this.rows key="@index" as |row|}}
        <div class="workflows-configurator-if__row">
          <div class="workflows-configurator-if__top">
            <div class="workflows-configurator-if__left">
              <ParameterField
                @value={{row.condition.leftValue}}
                @onChange={{fn this.updateConditionLeftExpression row.index}}
              >
                <:default as |fixedValue|>
                  <select
                    {{on "change" (fn this.updateConditionField row.index)}}
                  >
                    <option value="">--</option>
                    {{#each this.fieldOptions as |fieldOption|}}
                      <option
                        value={{fieldOption.id}}
                        selected={{eq fieldOption.id fixedValue}}
                      >
                        {{fieldOption.label}}
                      </option>
                    {{/each}}
                  </select>
                </:default>
              </ParameterField>
            </div>

            <div class="workflows-configurator-if__operator">
              <select
                {{on "change" (fn this.updateConditionOperator row.index)}}
              >
                {{#each row.operators as |operator|}}
                  <option
                    value={{operator}}
                    selected={{eq operator row.operation}}
                  >
                    {{i18n
                      (concat
                        "discourse_workflows.if_condition.operators." operator
                      )
                    }}
                  </option>
                {{/each}}
              </select>
            </div>
          </div>

          <div class="workflows-configurator-if__bottom">
            {{#unless row.isSingleValue}}
              <div class="workflows-configurator-if__right">
                <ParameterField
                  @value={{row.condition.rightValue}}
                  @onChange={{fn this.updateConditionValue row.index}}
                >
                  <:default as |fixedValue onFixedInput|>
                    <input
                      type="text"
                      value={{fixedValue}}
                      {{on "input" onFixedInput}}
                    />
                  </:default>
                </ParameterField>
              </div>
            {{/unless}}

            <div class="workflows-configurator-if__delete">
              <DButton
                @action={{fn this.removeCondition row.index}}
                @icon="trash-can"
                class="btn-transparent btn-small btn-danger"
              />
            </div>
          </div>
        </div>
      {{/each}}

      <DButton
        @action={{this.addCondition}}
        @icon="plus"
        @label="discourse_workflows.if_condition.add_condition"
        class="btn-default btn-small"
      />

      {{#unless this.rows.length}}
        <p class="workflows-configurator__hint">
          {{i18n "discourse_workflows.if_condition.no_conditions"}}
        </p>
      {{/unless}}
    </div>
  </template>
}
