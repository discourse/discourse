import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import {
  normalizeOptions,
  propertyOptionLabel,
} from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

export default class SelectControl extends Component {
  get noneKey() {
    return this.args.schema?.control_options?.none;
  }

  get includeNone() {
    return Boolean(this.noneKey);
  }

  get nonePlaceholder() {
    return this.noneKey ? i18n(this.noneKey) : undefined;
  }

  get options() {
    return normalizeOptions(this.args.schema.options).map((option) => ({
      ...option,
      label: propertyOptionLabel(
        this.args.nodeDefinition,
        this.args.fieldName,
        option
      ),
    }));
  }

  <template>
    <ExpressionWrapper
      @dynamicValueHint={{@dynamicValueHint}}
      @field={{@field}}
      @placeholder={{@placeholder}}
      @schema={{@schema}}
      @session={{@session}}
      @supportsExpression={{@supportsExpression}}
    >
      <@field.Control
        @includeNone={{this.includeNone}}
        @nonePlaceholder={{this.nonePlaceholder}}
        as |c|
      >
        {{#each this.options as |choice|}}
          <c.Option @value={{choice.value}}>{{choice.label}}</c.Option>
        {{/each}}
      </@field.Control>
    </ExpressionWrapper>
  </template>
}
