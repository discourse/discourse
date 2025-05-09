import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import FieldInputDescription from "admin/components/schema-setting/field-input-description";
import ComboBox from "select-kit/components/combo-box";

export default class SchemaSettingTypeEnum extends Component {
  @tracked
  value =
    this.args.value || (this.args.spec.required && this.args.spec.default);

  get content() {
    return this.args.spec.choices.map((choice) => {
      return {
        name: choice,
        id: choice,
      };
    });
  }

  @action
  onInput(newVal) {
    this.value = newVal;
    this.args.onChange(newVal);
  }

  <template>
    <ComboBox
      @content={{this.content}}
      @value={{this.value}}
      @onChange={{this.onInput}}
    />
    <FieldInputDescription @description={{@description}} />
  </template>
}
