import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { splitString } from "discourse/lib/utilities";
import ListSetting from "discourse/select-kit/components/list-setting";

const TOKEN_SEPARATOR = "|";
const WILDCARD = /[?*]/;

export default class SettingFieldHostList extends Component {
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
      <ListSetting
        @choices={{this.hosts}}
        @onChange={{this.onChange}}
        @options={{hash allowAny=true disabled=@field.disabled}}
        @settingName={{@definition.key}}
        @value={{this.hosts}}
      />
    </@field.Control>
  </template>
}
