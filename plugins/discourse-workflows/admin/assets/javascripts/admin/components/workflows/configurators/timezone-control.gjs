import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import TimezoneInput from "discourse/select-kit/components/timezone-input";
import { propertySelectNoneKey } from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

export default class TimezoneControl extends Component {
  get none() {
    return (
      this.args.schema?.control_options?.none ||
      propertySelectNoneKey(this.args.nodeDefinition, this.args.fieldName)
    );
  }

  get clearable() {
    return !this.args.schema?.required;
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
      <TimezoneInput
        @value={{@field.value}}
        @onChange={{@field.set}}
        @options={{hash none=this.none clearable=this.clearable}}
      />
    </ExpressionWrapper>
  </template>
}
