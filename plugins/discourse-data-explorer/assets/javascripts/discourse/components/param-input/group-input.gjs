import Component from "@glimmer/component";
import { service } from "@ember/service";
import GroupChooser from "select-kit/components/group-chooser";

export default class GroupInput extends Component {
  @service site;

  get allGroups() {
    return this.site.get("groups");
  }

  get groupChooserOption() {
    return this.args.info.type === "group_id"
      ? {
          maximum: 1,
        }
      : {};
  }

  <template>
    <@field.Custom id={{@field.id}}>
      <GroupChooser
        @content={{this.allGroups}}
        @value={{@field.value}}
        @labelProperty="name"
        @valueProperty="name"
        @onChange={{@field.set}}
        @options={{this.groupChooserOption}}
        name={{@info.identifier}}
      />
    </@field.Custom>
  </template>
}
