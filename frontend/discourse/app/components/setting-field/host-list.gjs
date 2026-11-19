import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { splitString } from "discourse/lib/utilities";
import ListSetting from "discourse/select-kit/components/list-setting";
import DSelect from "discourse/ui-kit/select/d-select";

const TOKEN_SEPARATOR = "|";
const WILDCARD = /[?*]/;

/** Whether a typed host can be stored: no wildcard, and no separator splitting it in two. */
export function isStorableHost(host) {
  return !WILDCARD.test(host) && !host.includes(TOKEN_SEPARATOR);
}

/** A host as the new picker's record. */
export function hostRecord(host) {
  const name = host.trim();
  return { id: name, name };
}

export default class SettingFieldHostList extends Component {
  @service siteSettings;

  /** The held hosts, which are the only ones the new picker lists. */
  get hostRecords() {
    return this.hosts.map(hostRecord);
  }

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
        <DSelect
          @allowCreate={{isStorableHost}}
          @createOption={{hostRecord}}
          @disabled={{@field.disabled}}
          @multiple={{true}}
          @onChange={{this.onChange}}
          @options={{this.hostRecords}}
          @texts={{hash ariaLabel=@field.title}}
          @value={{this.hosts}}
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
