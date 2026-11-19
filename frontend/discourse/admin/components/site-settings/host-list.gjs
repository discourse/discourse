import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import HostListSelect from "discourse/components/setting-field/host-list-select";
import ListSetting from "discourse/select-kit/components/list-setting";

export default class HostList extends Component {
  @service siteSettings;

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
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <HostListSelect
          @ariaLabel={{@label}}
          @disabled={{@disabled}}
          @hosts={{this.settingValue}}
          @onChange={{this.onChange}}
        />
      {{else}}
        <ListSetting
          @choices={{this.settingValue}}
          @onChange={{this.onChange}}
          @options={{hash allowAny=@allowAny disabled=@disabled}}
          @settingName={{@setting.setting}}
          @value={{this.settingValue}}
        />
      {{/if}}
    </div>
  </template>
}
