import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ExpressionWrapper from "./expression-wrapper";

export default class CategoryControl extends Component {
  get clearable() {
    return !this.args.schema?.required;
  }

  @action
  handleChange(categoryId) {
    this.args.field.set(categoryId == null ? "" : String(categoryId));
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
      <CategoryChooser
        @value={{if @field.value @field.value null}}
        @onChange={{this.handleChange}}
        @options={{hash clearable=this.clearable}}
      />
    </ExpressionWrapper>
  </template>
}
