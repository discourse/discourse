import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ColorList from "discourse/admin/components/color-list";
import CompactListControl from "discourse/components/setting-field/compact-list";

const TOKEN_SEPARATOR = "|";

export default class SettingFieldColorList extends Component {
  @service siteSettings;

  @action
  onChange(colors) {
    this.args.field.set(colors.join(TOKEN_SEPARATOR));
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <@field.Control>
        <ColorList
          @disabled={{@field.disabled}}
          @onChange={{this.onChange}}
          @values={{@field.value}}
        />
      </@field.Control>
    {{else}}
      <CompactListControl @definition={{@definition}} @field={{@field}} />
    {{/if}}
  </template>
}
