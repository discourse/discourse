import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
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

function valueForModeToggle(value) {
  if (value === null || value === undefined) {
    return "";
  }

  return String(value);
}

function booleanValueForPlainMode(value) {
  const plainValue = value.startsWith("=") ? value.slice(1) : value;
  // Unwrap literal expressions so "={{ true }}" round-trips to a plain true.
  const literal =
    plainValue.trim().match(/^\{\{\s*(.*?)\s*\}\}$/)?.[1] ?? plainValue;

  return ["true", "1"].includes(literal.trim().toLowerCase());
}

export default class BooleanControl extends Component {
  // Derived, not tracked, so a dropped variable flips the mode.
  get expressionMode() {
    return (
      this.supportsExpression &&
      isExpression(this.args.configuration?.[this.args.fieldName])
    );
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
    // Guards on the field, not `expressionMode`, which is false without a `@configuration`.
    if (wantsDynamic === isExpression(field.value)) {
      return;
    }

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
        @showOptional={{@showOptional}}
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
        @showOptional={{@showOptional}}
        @validation={{this.validation}}
        as |field|
      >
        <ExpressionWrapper
          @expressionMode={{false}}
          @field={{field}}
          @schema={{@schema}}
          @supportsExpression={{this.supportsExpression}}
          @session={{@session}}
          @modeControlClass="--toggle"
          @onModeChange={{fn this.onModeChange field}}
        >
          <field.Control />
        </ExpressionWrapper>
      </@form.Field>
    {{/if}}
  </template>
}
