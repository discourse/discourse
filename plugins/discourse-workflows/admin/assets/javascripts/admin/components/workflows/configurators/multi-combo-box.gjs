import Component from "@glimmer/component";
import MultiSelect from "discourse/select-kit/components/multi-select";
import {
  formatOptionValue,
  normalizeOptions,
  propertyOptionLabel,
} from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

export default class MultiComboBox extends Component {
  get options() {
    const optionFormat = this.args.schema?.ui?.option_format;
    return normalizeOptions(this.args.schema.options).map((option) => ({
      id: option.value,
      name: optionFormat
        ? formatOptionValue(option.value, optionFormat)
        : propertyOptionLabel(
            this.args.nodeDefinition,
            this.args.fieldName,
            option
          ),
    }));
  }

  get value() {
    const val = this.args.field.value;
    return Array.isArray(val) ? val : [];
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
    >
      <MultiSelect
        @content={{this.options}}
        @value={{this.value}}
        @onChange={{@field.set}}
      />
    </ExpressionWrapper>
  </template>
}
