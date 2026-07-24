import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { makeArray } from "discourse/lib/helpers";
import ListSetting from "discourse/select-kit/components/list-setting";

const TOKEN_SEPARATOR = "|";

export default class SettingFieldCompactList extends Component {
  @tracked createdChoices = null;

  get hasEnumChoices() {
    return this.args.definition.valid_values?.length > 0;
  }

  get allowAny() {
    return this.args.definition.allow_any !== false;
  }

  get settingValue() {
    return (this.args.field.value ?? "")
      .toString()
      .split(TOKEN_SEPARATOR)
      .filter(Boolean);
  }

  get choices() {
    if (this.hasEnumChoices) {
      return this.args.definition.valid_values.map((v) => ({
        name: v.name,
        value: String(v.value),
      }));
    }

    return uniqueItemsFromArray([
      ...this.settingValue,
      ...makeArray(this.args.definition.choices),
      ...makeArray(this.createdChoices),
    ]);
  }

  @action
  onChange(values) {
    this.args.field.set(makeArray(values).join(TOKEN_SEPARATOR));
  }

  @action
  onChangeChoices(choices) {
    this.createdChoices = uniqueItemsFromArray([
      ...makeArray(this.createdChoices),
      ...makeArray(choices),
    ]);
  }

  <template>
    <@field.Control>
      <ListSetting
        @value={{this.settingValue}}
        @choices={{this.choices}}
        @settingName={{@definition.key}}
        @nameProperty={{if this.hasEnumChoices "name"}}
        @valueProperty={{if this.hasEnumChoices "value"}}
        @onChange={{this.onChange}}
        @onChangeChoices={{this.onChangeChoices}}
        @options={{hash allowAny=this.allowAny}}
        @mandatoryValues={{@definition.mandatory_values}}
      />
    </@field.Control>
  </template>
}
