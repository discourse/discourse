import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

export default class SchemaThemeSettingTypeInteger extends Component {
  @action
  onInput(event) {
    this.args.onChange(event.currentTarget.value);
  }

  <template>
    <Input @value={{@value}} {{on "input" this.onInput}} @type="number" />
  </template>
}
