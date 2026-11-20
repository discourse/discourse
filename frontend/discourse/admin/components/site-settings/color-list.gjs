import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ColorList from "discourse/admin/components/color-list";
import CompactList from "discourse/admin/components/site-settings/compact-list";

const TOKEN_SEPARATOR = "|";

export default class SiteSettingColorList extends Component {
  @service siteSettings;

  @action
  onChange(colors) {
    this.args.changeValueCallback(colors.join(TOKEN_SEPARATOR));
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <ColorList
        @disabled={{@disabled}}
        @onChange={{this.onChange}}
        @values={{@value}}
      />
    {{else}}
      <CompactList
        @allowAny={{@allowAny}}
        @changeValueCallback={{@changeValueCallback}}
        @disabled={{@disabled}}
        @label={{@label}}
        @setting={{@setting}}
        @value={{@value}}
      />
    {{/if}}
  </template>
}
