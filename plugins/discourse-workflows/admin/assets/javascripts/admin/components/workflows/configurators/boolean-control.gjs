import Component from "@glimmer/component";
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

  <template>
    {{#if this.expressionMode}}
      <@form.Field
        @format={{this.format}}
        @name={{@fieldName}}
        @onSet={{@onSet}}
        @showOptional={{@showOptional}}
        @title={{this.label}}
        @tooltip={{this.tooltip}}
        @type="custom"
        @validation={{this.validation}}
        as |field|
      >
        <field.Control>
          <ExpressionWrapper
            @dynamicValueHint={{@dynamicValueHint}}
            @field={{field}}
            @placeholder={{this.placeholder}}
            @schema={{@schema}}
            @session={{@session}}
            @supportsExpression={{this.supportsExpression}}
          />
        </field.Control>
      </@form.Field>
    {{else}}
      <@form.Field
        @format={{this.format}}
        @name={{@fieldName}}
        @onSet={{@onSet}}
        @showOptional={{@showOptional}}
        @title={{this.label}}
        @tooltip={{this.tooltip}}
        @type="toggle"
        @validation={{this.validation}}
        as |field|
      >
        <ExpressionWrapper
          @field={{field}}
          @schema={{@schema}}
          @session={{@session}}
          @supportsExpression={{this.supportsExpression}}
        >
          <field.Control />
        </ExpressionWrapper>
      </@form.Field>
    {{/if}}
  </template>
}
