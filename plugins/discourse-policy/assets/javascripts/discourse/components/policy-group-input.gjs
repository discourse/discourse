import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import GroupChooser from "select-kit/components/group-chooser";

export default class PolicyGroupInput extends Component {
  @service site;

  get selectedGroups() {
    return (this.args.groups || "").split(",").filter(Boolean);
  }

  get availableGroups() {
    return (this.site.groups || [])
      .map((g) =>
        // prevents group "everyone" to be listed
        g.id === 0 ? null : g.name
      )
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
