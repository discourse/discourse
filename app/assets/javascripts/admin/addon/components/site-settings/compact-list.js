import { action, computed } from "@ember/object";
import Component from "@ember/component";
import { makeArray } from "discourse-common/lib/helpers";

export default class CompactList extends Component {
  tokenSeparator = "|";
  createdChoices = null;

  @computed("value")
  get settingValue() {
    return this.value.toString().split(this.tokenSeparator).filter(Boolean);
  }

  @computed("settingValue", "setting.choices.[]", "createdChoices.[]")
  get settingChoices() {
    return [
      ...new Set([
        ...makeArray(this.settingValue),
        ...makeArray(this.setting.choices),
        ...makeArray(this.createdChoices),
      ]),
    ];
  }

  @action
  onChangeListSetting(value) {
    this.set("value", value.join(this.tokenSeparator));
  }

  @action
  onChangeChoices(choices) {
    this.set("createdChoices", [
      ...new Set([...makeArray(this.createdChoices), ...makeArray(choices)]),
    ]);
  }
}
