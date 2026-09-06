import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import CategoryChooser from "discourse/select-kit/components/category-chooser";

export default class CategoryChooserExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <CategoryChooser @value={{this.value}} @onChange={{this.onChange}} />
  </template>
}
