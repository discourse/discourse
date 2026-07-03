import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import {
  isSingleValueOperator,
  operatorsForType,
} from "../../../lib/workflows/condition-operators";
import {
  inputConnectionsForNode,
  inputFieldPrefixForConnection,
  inputIndexForConnection,
  inputSummaryForNode,
  outputIndexForConnection,
  previousNodeForConnection,
  schemaFieldsForNodeInput,
} from "../../../lib/workflows/data-schema";
import { isExpression } from "../../../lib/workflows/property-engine";
import Collection from "./collection";
import Field from "./field";

function flattenFields(fields, prefix = "", labelPrefix = "") {
  const result = [];
  for (const field of fields) {
    const path = prefix ? `${prefix}.${field.key}` : field.key;
    if (field.children?.length) {
      result.push(...flattenFields(field.children, path, labelPrefix));
    } else {
      result.push({
        id: field.id || path,
        label: labelPrefix ? `${labelPrefix}.${path}` : path,
        type: field.type,
      });
    }
  }
  return result;
}

const CATEGORY_FIELDS = ["category_id", "category"];
const USER_FIELDS = ["username"];

function leafKey(fieldPath) {
  if (!fieldPath) {
    return fieldPath;
  }

  let path = fieldPath;
  if (typeof path === "object") {
    path = path.value ?? path.id ?? path.label ?? "";
  }
  path = String(path);

  const exprMatch = path.match(/^=\{\{\s*(.*?)\s*\}\}$/);
  if (exprMatch) {
    path = exprMatch[1];
  }

  const bracketSegments = [
    ...path.matchAll(/\[((?:"(?:\\.|[^"\\])*")|(?:'(?:\\.|[^'\\])*'))\]/g),
  ];
  if (bracketSegments.length) {
    return unquoteBracketSegment(bracketSegments.at(-1)[1]);
  }

  const parts = path.split(".");
  return parts[parts.length - 1];
}

function unquoteBracketSegment(segment) {
  if (segment.startsWith('"')) {
    try {
      return JSON.parse(segment);
    } catch {
      return segment.slice(1, -1);
    }
  }

  return segment.slice(1, -1).replace(/\\([\\'])/g, "$1");
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
  @tracked conditionSchemas = (
    this.args.formApi?.get(this.args.fieldName) || []
  ).map((item) => this.#buildConditionSchema(item));

  #buildConditionSchema(item) {
    return {
      opSchema: operationSchema(item),
      singleValue: isSingleValueOperator(item?.operator?.operation),
      rvSchema: rightValueSchema(item),
    };
  }

  #updateSchemaAtIndex(index, schema) {
    const newSchemas = [...this.conditionSchemas];
    newSchemas[index] = schema;
    this.conditionSchemas = newSchemas;
  }

  get fieldOptions() {
    if (this.args.fieldOptions) {
      return this.args.fieldOptions;
    }

    const graph = {
      nodes: this.args.nodes || [],
      connections: this.args.connections || [],
      nodeTypes: this.args.nodeTypes || [],
    };
    const runData = this.args.session?.lastExecutionRunData || {};
    const inputConnections = inputConnectionsForNode(this.args.node, graph);
    const primaryConnection = inputConnections[0] || null;

    return inputConnections.flatMap((connection) => {
      const previousNode = previousNodeForConnection(connection, graph);
      if (!previousNode) {
        return [];
      }

      const inputIndex = inputIndexForConnection(connection);
      const outputIndex = outputIndexForConnection(connection);
      const currentInputSummary = this.args.node
        ? inputSummaryForNode(runData, this.args.node.name, inputIndex, {
            node: this.args.node,
            sourceNode: previousNode,
            outputIndex,
          })
        : null;
      const prefix = inputFieldPrefixForConnection(connection, previousNode, {
        primaryConnection,
      });
      const fields = currentInputSummary
        ? schemaFieldsForNodeInput(runData, this.args.node.name, {
            inputIndex,
            node: this.args.node,
            sourceNode: previousNode,
            outputIndex,
            prefix,
          })
        : [];
      const labelPrefix =
        inputConnections.length > 1 ? previousNode.name || null : null;

      return flattenFields(fields, "", labelPrefix);
    });
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
    this.conditionSchemas = [
      ...this.conditionSchemas,
      this.#buildConditionSchema(item),
    ];
  }

  @action
  removeCondition(index) {
    const newSchemas = [...this.conditionSchemas];
    newSchemas.splice(index, 1);
    this.conditionSchemas = newSchemas;
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
      : `={{ ${field?.id || value} }}`;
    set(name, storedValue);

    const operation = operatorsForType(type)[0];
    const basePath = `${this.args.fieldName}.${index}`;

    set(`${basePath}.operator`, {
      operation,
      type,
      singleValue: isSingleValueOperator(operation),
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
      isSingleValueOperator(value)
    );

    this.#updateSchemaAtIndex(index, {
      ...this.conditionSchemas[index],
      singleValue: isSingleValueOperator(value),
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
      @session={{@session}}
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
        @session={{@session}}
        @onSet={{fn this.handleLeftValueSet ctx.index}}
      />

      {{#let (get this.conditionSchemas ctx.index) as |schemas|}}
        <ctx.object.Object @name="operator" as |operator|>
          <Field
            @form={{operator}}
            @formApi={{@formApi}}
            @configuration={{ctx.item.operator}}
            @fieldName="operation"
            @schema={{schemas.opSchema}}
            @label={{i18n "discourse_workflows.if.operator"}}
            @session={{@session}}
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
            @session={{@session}}
          />
        {{/unless}}
      {{/let}}
    </Collection>
  </template>
}
