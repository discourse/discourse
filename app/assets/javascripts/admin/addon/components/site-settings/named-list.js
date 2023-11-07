import Component from "@ember/component";
import { action, computed } from "@ember/object";

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
}
