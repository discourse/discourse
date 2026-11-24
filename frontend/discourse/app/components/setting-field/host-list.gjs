import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SelectHostList from "discourse/components/setting-field/-internals/select-host-list";
import { splitString } from "discourse/lib/utilities";
import ListSetting from "discourse/select-kit/components/list-setting";

const TOKEN_SEPARATOR = "|";
const WILDCARD = /[?*]/;

export default class SettingFieldHostList extends Component {
  @service siteSettings;

  get hosts() {
    return splitString(this.args.field.value, TOKEN_SEPARATOR);
  }

  @action
  onChange(hosts) {
    if (hosts.some((host) => WILDCARD.test(host))) {
      return;
    }

    this.args.field.set(hosts.join(TOKEN_SEPARATOR));
  }

  <template>
    <@field.Control>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <SelectHostList
          @ariaLabel={{@field.title}}
          @disabled={{@field.disabled}}
          @hosts={{this.hosts}}
          @onChange={{this.onChange}}
        />
      {{else}}
        <ListSetting
          @choices={{this.hosts}}
          @onChange={{this.onChange}}
          @options={{hash allowAny=true disabled=@field.disabled}}
          @settingName={{@definition.key}}
          @value={{this.hosts}}
        />
      {{/if}}
    </@field.Control>
  </template>
}
