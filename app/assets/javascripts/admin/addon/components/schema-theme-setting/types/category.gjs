import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import CategoryChooser from "select-kit/components/category-chooser";

export default class SchemaThemeSettingTypeCategory extends Component {
  @tracked value;

  constructor() {
    super(...arguments);
    this.value = this.args.value;
  }

  @action
  onInput(newVal) {
    this.value = newVal;
    this.args.onChange(newVal);
  }

  <template>
    <CategoryChooser
      @value={{this.value}}
      @onChange={{this.onInput}}
      @options={{hash allowUncategorized=false}}
    />
  </template>
}
