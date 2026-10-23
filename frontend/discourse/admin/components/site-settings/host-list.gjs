import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import ListSetting from "discourse/select-kit/components/list-setting";

export default class HostList extends Component {
  tokenSeparator = "|";

  get settingValue() {
    return this.args.value
      .toString()
      .split(this.tokenSeparator)
      .filter(Boolean);
  }

  @action
  onChange(value) {
    if (value.some((v) => v.includes("?") || v.includes("*"))) {
      return;
    }

    this.args.changeValueCallback(value.join(this.tokenSeparator));
  }

  <template>
    <div ...attributes>
      <ListSetting
        @choices={{this.settingValue}}
        @onChange={{this.onChange}}
        @options={{hash allowAny=@allowAny disabled=@disabled}}
        @settingName={{@setting.setting}}
        @value={{this.settingValue}}
      />
    </div>
  </template>
}
