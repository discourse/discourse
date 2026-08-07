import Component from "@glimmer/component";
import {
  normalizeOptions,
  propertyOptionLabel,
} from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

export default class SelectControl extends Component {
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
      @field={{@field}}
      @schema={{@schema}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      <@field.Control @includeNone={{false}} as |c|>
        {{#each this.options as |choice|}}
          <c.Option @value={{choice.value}}>{{choice.label}}</c.Option>
        {{/each}}
      </@field.Control>
    </ExpressionWrapper>
  </template>
}
