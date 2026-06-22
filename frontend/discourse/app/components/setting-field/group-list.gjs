import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { splitString } from "discourse/lib/utilities";
import GroupChooser from "discourse/select-kit/components/group-chooser";

export default class SettingFieldGroupList extends Component {
  @service site;

  get groupContent() {
    return this.site.groups;
  }

  toGroupIdArray(value) {
    if (Array.isArray(value)) {
      return value.map(Number);
    }
    return splitString(value, "|").map(Number);
  }

  @bind
  setGroupIdString(field, ids) {
    field.set((ids ?? []).join("|"));
  }

  <template>
    <@field.Control>
      <GroupChooser
        @content={{this.groupContent}}
        @value={{this.toGroupIdArray @field.value}}
        @labelProperty="name"
        @onChange={{fn this.setGroupIdString @field}}
      />
    </@field.Control>
  </template>
}
