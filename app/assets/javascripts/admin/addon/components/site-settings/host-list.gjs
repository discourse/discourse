import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import ListSetting from "select-kit/components/list-setting";

export default class HostList extends Component {
  tokenSeparator = "|";
  choices = null;

  @computed("value")
  get settingValue() {
    return this.value.toString().split(this.tokenSeparator).filter(Boolean);
  }

  @action
  onChange(value) {
    if (value.some((v) => v.includes("?") || v.includes("*"))) {
      return;
    }

    this.set("value", value.join(this.tokenSeparator));
  }

  <template>
    <ListSetting
      @value={{this.settingValue}}
      @settingName={{this.setting.setting}}
      @choices={{this.settingValue}}
      @onChange={{this.onChange}}
      @options={{hash allowAny=this.allowAny}}
    />
  </template>
}
