import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  hostRecord,
  isStorableHost,
} from "discourse/components/setting-field/host-list";
import ListSetting from "discourse/select-kit/components/list-setting";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

export default class HostList extends Component {
  @service siteSettings;

  tokenSeparator = "|";

  /** The held hosts, which are the only ones the new picker lists. */
  get hostRecords() {
    return this.settingValue.map(hostRecord);
  }

  get settingValue() {
    return this.args.value
      .toString()
      .split(this.tokenSeparator)
      .filter(Boolean);
  }

  @action
  allowHost(filter) {
    return Boolean(this.args.allowAny) && isStorableHost(filter);
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
        <DSelect
          @allowCreate={{this.allowHost}}
          @createOption={{hostRecord}}
          @disabled={{@disabled}}
          @multiple={{true}}
          @onChange={{this.onChange}}
          @options={{this.hostRecords}}
          @texts={{hash
            ariaLabel=@label
            placeholder=(i18n "admin.site_settings.host_list.placeholder")
            addMorePlaceholder=(i18n
              "admin.site_settings.host_list.add_more_placeholder"
            )
            noResults=(i18n "admin.site_settings.host_list.not_allowed")
          }}
          @value={{this.settingValue}}
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
