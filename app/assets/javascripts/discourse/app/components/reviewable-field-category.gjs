import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import CategoryChooser from "select-kit/components/category-chooser";

export default class extends Component {
  @tracked categoryId = this.args.value;

  @action
  onChange(category) {
    this.categoryId = category;
    this.args.categoryChanged?.(category);
  }

  <template>
    <CategoryChooser @value={{this.categoryId}} @onChange={{this.onChange}} />
  </template>
}
