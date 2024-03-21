import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";

export default class SchemaThemeSettingTypeInteger extends Component {
  @action
  onInput(event) {
    this.args.onChange(parseInt(event.currentTarget.value, 10));
  }

  <template>
    <Input @value={{@value}} {{on "input" this.onInput}} @type="number" />

    <FieldInputDescription @description={{@description}} />
  </template>
}
