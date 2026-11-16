import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import ListSetting from "discourse/select-kit/components/list-setting";

export default class NamedList extends Component {
  tokenSeparator = "|";

  get settingValue() {
    return this.args.value
      .toString()
      .split(this.tokenSeparator)
      .filter(Boolean);
  }

  get settingChoices() {
    let choices = this.args.setting.choices;

    if (this.settingValue) {
      const valuesSet = new Set(choices.map((choice) => choice.value));

      choices = choices.concat(
        this.settingValue
          .filter((value) => !valuesSet.has(value))
          .map((value) => ({ name: value, value }))
      );
    }

    return choices;
  }

  @action
  onChangeListSetting(value) {
    this.args.changeValueCallback(value.join(this.tokenSeparator));
  }

  <template>
    <div ...attributes>
      <ListSetting
        @choices={{this.settingChoices}}
        @nameProperty="name"
        @onChange={{this.onChangeListSetting}}
        @options={{hash allowAny=@allowAny}}
        @settingName={{@setting.setting}}
        @value={{this.settingValue}}
        @valueProperty="value"
      />
    </div>
  </template>
}
