/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import ListSetting from "select-kit/components/list-setting";

export default class NamedList extends Component {
  tokenSeparator = "|";

  @computed("value")
  get settingValue() {
    return this.value.toString().split(this.tokenSeparator).filter(Boolean);
  }

  @computed("setting.choices.[]", "settingValue")
  get settingChoices() {
    let choices = this.setting.choices;

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
    this.set("value", value.join(this.tokenSeparator));
  }

  <template>
    <ListSetting
      @value={{this.settingValue}}
      @settingName={{this.setting.setting}}
      @choices={{this.settingChoices}}
      @nameProperty="name"
      @valueProperty="value"
      @onChange={{this.onChangeListSetting}}
      @options={{hash allowAny=this.allowAny}}
    />
  </template>
}
