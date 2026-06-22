import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DSegmentedControl from "discourse/components/d-segmented-control";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import {
  resolveVariableId,
  WORKFLOW_VARIABLE_MIME,
} from "../../../lib/workflows/expression-context";
import {
  fieldType,
  isExpression,
} from "../../../lib/workflows/property-engine";
import ExpressionInput from "./expression-input";

const MODE_ITEMS = [
  {
    value: "plain",
    icon: "paragraph",
    label: i18n("discourse_workflows.parameter_field.plain"),
  },
  {
    value: "dynamic",
    icon: "code",
    label: i18n("discourse_workflows.parameter_field.dynamic"),
  },
];

function plainTextValue(value) {
  if (value === null || value === undefined) {
    return "";
  }

  if (typeof value === "string") {
    return value;
  }

  if (typeof value === "object") {
    return JSON.stringify(value, null, 2);
  }

  return String(value);
}

function schemaType(schema) {
  return fieldType(schema);
}

function wholeExpressionBody(value) {
  const expressionBody = value.slice(1).trim();
  const match = expressionBody.match(/^\{\{\s*([\s\S]*?)\s*\}\}$/);

  return match?.[1]?.trim() || null;
}

function parseJsonLiteral(value) {
  try {
    return JSON.parse(value);
  } catch {
    return undefined;
  }
}

function splitListValue(value) {
  return String(value)
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function arrayLiteralValue(value) {
  if (Array.isArray(value)) {
    return value;
  }

  if (value === null || value === undefined || value === "") {
    return [];
  }

  return splitListValue(value);
}

function dynamicValueForModeToggle(value, schema = {}) {
  if (typeof value === "string" && value.startsWith("=")) {
    return value;
  }

  if (schemaType(schema) === "array" || Array.isArray(value)) {
    return `={{ ${JSON.stringify(arrayLiteralValue(value))} }}`;
  }

  return `=${plainTextValue(value)}`;
}

function plainArrayValueForModeToggle(expressionValue) {
  const parsedLiteral = parseJsonLiteral(
    wholeExpressionBody(expressionValue) || ""
  );

  if (Array.isArray(parsedLiteral)) {
    return parsedLiteral;
  }

  if (typeof parsedLiteral === "string") {
    return splitListValue(parsedLiteral);
  }

  const rawExpression = expressionValue.slice(1).trim();
  if (!rawExpression.includes("{{") && !rawExpression.includes("}}")) {
    return splitListValue(rawExpression);
  }

  return [];
}

function plainValueForModeToggle(value, schema = {}) {
  if (!(typeof value === "string" && value.startsWith("="))) {
    return value;
  }

  const type = schemaType(schema);

  if (type === "array") {
    return plainArrayValueForModeToggle(value);
  }

  const body = wholeExpressionBody(value);
  if (body) {
    const parsedLiteral = parseJsonLiteral(body);
    if (parsedLiteral !== undefined && typeof parsedLiteral !== "object") {
      return parsedLiteral;
    }
  }

  return value.slice(1);
}

export default class ExpressionWrapper extends Component {
  @service workflowsNodeTypes;

  @tracked isDragOver = false;
  dragEndHandler = null;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.dragEndHandler) {
      document.removeEventListener("dragend", this.dragEndHandler);
      this.dragEndHandler = null;
    }
  }

  get expressionMode() {
    if (this.args.expressionMode !== undefined) {
      return Boolean(this.args.expressionMode);
    }

    return isExpression(this.args.field?.value);
  }

  get modeItems() {
    return this.args.modeItems || MODE_ITEMS;
  }

  @action
  toggleMode(value) {
    if (this.args.onModeChange) {
      this.args.onModeChange(value);
      return;
    }

    const wantsDynamic = value === "dynamic";
    if (wantsDynamic === this.expressionMode) {
      return;
    }

    if (wantsDynamic) {
      this.args.field.set(
        dynamicValueForModeToggle(this.args.field.value, this.args.schema)
      );
    } else {
      this.args.field.set(
        plainValueForModeToggle(this.args.field.value, this.args.schema)
      );
    }
  }

  @action
  handleDragOver(event) {
    if (!this.args.supportsExpression) {
      return;
    }
    if (!event.dataTransfer.types.includes(WORKFLOW_VARIABLE_MIME)) {
      return;
    }
    event.preventDefault();
    event.dataTransfer.dropEffect = "copy";
    this.isDragOver = true;

    // Safety: clear on next dragend in case dragleave doesn't fire
    if (!this.dragEndHandler) {
      this.dragEndHandler = () => {
        this.isDragOver = false;
        document.removeEventListener("dragend", this.dragEndHandler);
        this.dragEndHandler = null;
      };
      document.addEventListener("dragend", this.dragEndHandler, {
        once: true,
      });
    }
  }

  @action
  handleDragLeave(event) {
    if (!event.currentTarget.contains(event.relatedTarget)) {
      this.isDragOver = false;
    }
  }

  @action
  handleDrop(event) {
    this.isDragOver = false;

    if (!this.args.supportsExpression || this.expressionMode) {
      return;
    }

    const data = event.dataTransfer.getData(WORKFLOW_VARIABLE_MIME);
    if (!data) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    let variable;
    try {
      variable = JSON.parse(data);
    } catch {
      return;
    }

    const prefix =
      this.workflowsNodeTypes.expressionContext.item_prefix || "$json";
    const variableId = resolveVariableId(variable, prefix);

    this.args.field.set(`={{ ${variableId} }}`);
  }

  <template>
    <div
      class={{dConcatClass
        "workflows-property-engine__control-wrapper"
        (if this.isDragOver "is-drag-over")
      }}
      data-supports-expression={{if @supportsExpression "true"}}
      {{on "dragover" this.handleDragOver}}
      {{on "dragleave" this.handleDragLeave}}
      {{on "drop" this.handleDrop}}
    >
      {{#if this.expressionMode}}
        <ExpressionInput
          @field={{@field}}
          @placeholder={{@placeholder}}
          @session={{@session}}
          @autofocus={{true}}
        />
        {{#if @dynamicValueHint}}
          <p class="workflows-property-engine__dynamic-hint">
            {{@dynamicValueHint}}
          </p>
        {{/if}}
      {{else}}
        {{yield}}
      {{/if}}

      {{#if @supportsExpression}}
        <DSegmentedControl
          @items={{this.modeItems}}
          @value={{if this.expressionMode "dynamic" "plain"}}
          @onSelect={{this.toggleMode}}
          @size="small"
          class="workflows-property-engine__mode-control"
        />
      {{/if}}
    </div>
  </template>
}
