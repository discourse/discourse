import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { AUTO_GROUPS } from "discourse/lib/constants";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";

const AUTOMATIC_GROUP_IDS = new Set(
  Object.values(AUTO_GROUPS).map((g) => g.id)
);

export default class PolicyGroupInput extends Component {
  @service site;
  @service siteSettings;

  get selectedGroups() {
    return (this.args.groups || "").split(",").filter(Boolean);
  }

  get groups() {
    return (this.site.groups || []).filter((g) => {
      if (this.args.excludeAutomaticGroups) {
        return !g.automatic && !AUTOMATIC_GROUP_IDS.has(g.id);
      }

      return g.id !== AUTO_GROUPS.everyone.id;
    });
  }

  get availableGroups() {
    return this.groups.map((g) => g.name);
  }

  @action
  onChange(values) {
    this.args.onChangeGroup?.(values.join(","));
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup) }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectGroup
        @emit="names"
        @items={{this.groups}}
        @multiple={{true}}
        @onChange={{this.onChange}}
        @value={{this.selectedGroups}}
      />
    {{else}}
      {{! TODO (select-kit-replacement-cleanup) }}
      <GroupChooser
        @content={{this.availableGroups}}
        @nameProperty={{null}}
        @onChange={{this.onChange}}
        @value={{this.selectedGroups}}
        @valueProperty={{null}}
      />
    {{/if}}
  </template>
}
