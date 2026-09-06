import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import CategoryChooser from "discourse/select-kit/components/category-chooser";

export default class SettingFieldCategory extends Component {
  get categoryId() {
    const id = parseInt(this.args.field.value, 10);
    return isNaN(id) ? null : id;
  }

  @action
  onChange(categoryId) {
    this.args.field.set(String(categoryId ?? ""));
  }

  <template>
    <@field.Control>
      <CategoryChooser
        @value={{this.categoryId}}
        @onChange={{this.onChange}}
        @options={{hash
          allowUncategorized=true
          none=true
          disabled=@field.disabled
        }}
      />
    </@field.Control>
  </template>
}
