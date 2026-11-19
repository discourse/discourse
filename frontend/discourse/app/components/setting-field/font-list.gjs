import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FontSelector from "discourse/select-kit/components/font-selector";

export default class SettingFieldFontList extends Component {
  get choices() {
    return this.args.definition.choices.map(({ value, name }) => ({
      classNames: `body-font-${value.replace(/_/g, "-")}`,
      id: value,
      name,
    }));
  }

  <template>
    <@field.Control>
      <FontSelector
        @content={{this.choices}}
        @onChange={{@field.set}}
        @options={{hash disabled=@field.disabled}}
        @value={{@field.value}}
      />
    </@field.Control>
  </template>
}
