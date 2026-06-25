import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { bind } from "discourse/lib/decorators";
import { splitString } from "discourse/lib/utilities";
import ListSetting from "discourse/select-kit/components/list-setting";

export default class SettingFieldCompactList extends Component {
  get hasEnumChoices() {
    return this.args.definition.valid_values?.length > 0;
  }

  get choices() {
    if (this.hasEnumChoices) {
      return this.args.definition.valid_values.map((v) => ({
        name: v.name,
        value: String(v.value),
      }));
    }
    return this.args.definition.choices;
  }

  @bind
  setList(field, values) {
    field.set(Array.isArray(values) ? values.join("|") : values);
  }

  <template>
    <@field.Control>
      <ListSetting
        @value={{splitString @field.value "|"}}
        @choices={{this.choices}}
        @settingName={{@definition.key}}
        @nameProperty={{if this.hasEnumChoices "name"}}
        @valueProperty={{if this.hasEnumChoices "value"}}
        @onChange={{fn this.setList @field}}
      />
    </@field.Control>
  </template>
}
