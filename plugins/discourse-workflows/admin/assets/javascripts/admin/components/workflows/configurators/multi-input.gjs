import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { makeArray } from "discourse/lib/helpers";
import MultiSelect from "discourse/select-kit/components/multi-select";
import ExpressionWrapper from "./expression-wrapper";

export default class MultiInput extends Component {
  get value() {
    return makeArray(this.args.field.value);
  }

  get content() {
    return this.value.map((value) => ({ id: value, name: String(value) }));
  }

  @action
  handleChange(values) {
    this.args.field.set(makeArray(values));
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
      <MultiSelect
        @content={{this.content}}
        @nameProperty="name"
        @onChange={{this.handleChange}}
        @options={{hash allowAny=true}}
        @value={{this.value}}
        @valueProperty="id"
      />
    </ExpressionWrapper>
  </template>
}
