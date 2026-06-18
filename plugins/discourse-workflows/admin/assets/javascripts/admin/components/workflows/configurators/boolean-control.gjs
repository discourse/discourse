import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DSegmentedControl from "discourse/components/d-segmented-control";
import { i18n } from "discourse-i18n";
import {
  fieldFormat,
  fieldShowDescription,
  fieldSupportsExpression,
  isExpression,
  propertyDescription,
  propertyLabel,
  propertyPlaceholder,
} from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

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

function valueForModeToggle(value) {
  if (value === null || value === undefined) {
    return "";
  }

  return String(value);
}

function booleanValueForPlainMode(value) {
  const plainValue = value.startsWith("=") ? value.slice(1) : value;

  return ["true", "1"].includes(plainValue.trim().toLowerCase());
}

export default class BooleanControl extends Component {
  @tracked expressionMode = this.#initialExpressionMode();

  #initialExpressionMode() {
    if (!fieldSupportsExpression(this.args.schema)) {
      return false;
    }
    return isExpression(this.args.configuration?.[this.args.fieldName]);
  }

  get supportsExpression() {
    return fieldSupportsExpression(this.args.schema);
  }

  get format() {
    return fieldFormat(this.args.schema);
  }

  get label() {
    return (
      this.args.label ||
      propertyLabel(this.args.nodeDefinition, this.args.fieldName)
    );
  }

  get placeholder() {
    return propertyPlaceholder(this.args.nodeDefinition, this.args.fieldName);
  }

  get tooltip() {
    if (!fieldShowDescription(this.args.schema)) {
      return undefined;
    }
    return propertyDescription(this.args.nodeDefinition, this.args.fieldName);
  }

  get validation() {
    return this.args.schema?.required ? "required" : undefined;
  }

  @action
  onModeChange(field, value) {
    const wantsDynamic = value === "dynamic";
    if (wantsDynamic === this.expressionMode) {
      return;
    }

    this.expressionMode = wantsDynamic;
    const currentValue = valueForModeToggle(field.value);

    if (wantsDynamic) {
      field.set(
        currentValue.startsWith("=") ? currentValue : `=${currentValue}`
      );
    } else {
      field.set(booleanValueForPlainMode(currentValue));
    }
  }

  <template>
    {{#if this.expressionMode}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.label}}
        @showTitle={{true}}
        @type="custom"
        @format={{this.format}}
        @onSet={{@onSet}}
        as |field|
      >
        <field.Control>
          <ExpressionWrapper
            @expressionMode={{true}}
            @field={{field}}
            @schema={{@schema}}
            @placeholder={{this.placeholder}}
            @supportsExpression={{this.supportsExpression}}
            @dynamicValueHint={{@dynamicValueHint}}
            @session={{@session}}
            @modeItems={{MODE_ITEMS}}
            @onModeChange={{fn this.onModeChange field}}
          />
        </field.Control>
      </@form.Field>
    {{else}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.label}}
        @tooltip={{this.tooltip}}
        @type="toggle"
        @format={{this.format}}
        @validation={{this.validation}}
        as |field|
      >
        <field.Control />
        {{#if this.supportsExpression}}
          <DSegmentedControl
            @items={{MODE_ITEMS}}
            @value="plain"
            @onSelect={{fn this.onModeChange field}}
            @size="small"
            class="workflows-property-engine__mode-control --toggle"
          />
        {{/if}}
      </@form.Field>
    {{/if}}
  </template>
}
