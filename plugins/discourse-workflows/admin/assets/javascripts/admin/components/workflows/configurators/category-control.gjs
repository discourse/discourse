import Component from "@glimmer/component";
import { action } from "@ember/object";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ExpressionWrapper from "./expression-wrapper";

export default class CategoryControl extends Component {
  @action
  handleChange(categoryId) {
    this.args.field.set(categoryId == null ? "" : String(categoryId));
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
    >
      <CategoryChooser
        @value={{if @field.value @field.value null}}
        @onChange={{this.handleChange}}
      />
    </ExpressionWrapper>
  </template>
}
