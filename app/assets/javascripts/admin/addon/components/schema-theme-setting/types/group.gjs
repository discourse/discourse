import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";
import ComboBoxComponent from "select-kit/components/combo-box";

export default class SchemaThemeSettingTypeGroup extends Component {
  @service site;
  @tracked value = this.args.value;

  required = this.args.spec.required;

  @action
  onInput(newVal) {
    this.value = newVal;
    this.args.onChange(newVal);
  }

  get groupChooserOptions() {
    return {
      clearable: !this.required,
      filterable: true,
      none: null,
    };
  }

  <template>
    <ComboBoxComponent
      @content={{this.site.groups}}
      @value={{this.value}}
      @onChange={{this.onInput}}
      @options={{this.groupChooserOptions}}
    />

    <FieldInputDescription @description={{@description}} />
  </template>
}
