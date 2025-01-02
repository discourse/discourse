import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import CategoryChooser from "select-kit/components/category-chooser";

export default class Category extends Component {
  @action
  onChange(value) {
    this.args.changeValueCallback(value);
  }

  <template>
    <CategoryChooser
      @value={{@value}}
      @onChange={{this.onChange}}
      @options={{hash allowUncategorized=true none=(eq @setting.default "")}}
    />
  </template>
}
