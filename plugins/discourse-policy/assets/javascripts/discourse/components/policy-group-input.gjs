import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { AUTO_GROUPS } from "discourse/lib/constants";
import GroupChooser from "discourse/select-kit/components/group-chooser";

const AUTOMATIC_GROUP_IDS = new Set(
  Object.values(AUTO_GROUPS).map((g) => g.id)
);

export default class PolicyGroupInput extends Component {
  @service site;

  get selectedGroups() {
    return (this.args.groups || "").split(",").filter(Boolean);
  }

  get availableGroups() {
    return (this.site.groups || [])
      .map((g) => {
        if (this.args.excludeAutomaticGroups) {
          return g.automatic || AUTOMATIC_GROUP_IDS.has(g.id) ? null : g.name;
        }

        return g.id === AUTO_GROUPS.everyone.id ? null : g.name;
      })
      .filter(Boolean);
  }

  @action
  onChange(values) {
    this.args.onChangeGroup?.(values.join(","));
  }

  <template>
    <GroupChooser
      @content={{this.availableGroups}}
      @valueProperty={{null}}
      @nameProperty={{null}}
      @value={{this.selectedGroups}}
      @onChange={{this.onChange}}
    />
  </template>
}
