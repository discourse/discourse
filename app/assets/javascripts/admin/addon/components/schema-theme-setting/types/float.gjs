import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

export default class SchemaThemeSettingTypeFloat extends Component {
  @action
  onInput(event) {
    this.args.onChange(parseFloat(event.currentTarget.value));
  }

  <template>
    <Input
      @value={{@value}}
      {{on "input" this.onInput}}
      @type="number"
      step="0.1"
    />
  </template>
}
