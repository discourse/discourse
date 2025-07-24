import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import ListSetting from "select-kit/components/list-setting";

export default class EnumList extends Component {
  tokenSeparator = "|";

  @computed("value")
  get settingValue() {
    return this.value.toString().split(this.tokenSeparator).filter(Boolean);
  }

  @action
  onChangeListSetting(value) {
    this.set("value", value.join(this.tokenSeparator));
  }

  <template>
    <ListSetting
      @value={{this.settingValue}}
      @settingName={{this.setting.setting}}
      @choices={{this.setting.validValues}}
      @nameProperty="name"
      @valueProperty="value"
      @onChange={{this.onChangeListSetting}}
      @options={{hash allowAny=this.allowAny}}
    />
  </template>
}
