import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";
import CategoryChooser from "select-kit/components/category-chooser";

export default class SchemaThemeSettingTypeCategory extends Component {
  @tracked value = this.args.value;
  required = this.args.spec.required;

  @action
  onInput(newVal) {
    this.value = newVal;
    this.args.onChange(newVal);
  }

  get categoryChooserOptions() {
    return {
      allowUncategorized: false,
      none: !this.required,
      clearable: !this.required,
    };
  }

  <template>
    <CategoryChooser
      @value={{this.value}}
      @onChange={{this.onInput}}
      @options={{this.categoryChooserOptions}}
    />

    <FieldInputDescription @description={{@description}} />
  </template>
}
