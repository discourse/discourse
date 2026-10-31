import Component from "@glimmer/component";
import { service } from "@ember/service";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";

const GROUPS = [
  { name: "staff", id: 1, automatic: false },
  { name: "lounge", id: 2, automatic: true },
  { name: "admin", id: 3, automatic: false },
];

const SELECTED = [1, 2];

export default class GroupChooserExample extends Component {
  @service siteSettings;

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectGroup
        @items={{GROUPS}}
        @multiple={{true}}
        @onChange={{@onChange}}
        @value={{SELECTED}}
      />
    {{else}}
      <GroupChooser
        @content={{GROUPS}}
        @onChange={{@onChange}}
        @selected={{SELECTED}}
      />
    {{/if}}
  </template>
}
