import Component from "@glimmer/component";
import { service } from "@ember/service";
import GroupChooser from "discourse/select-kit/components/group-chooser";

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
    <@Control id={{@field.id}}>
      <GroupChooser
        name={{@info.identifier}}
        @content={{this.allGroups}}
        @labelProperty="name"
        @onChange={{@field.set}}
        @options={{this.groupChooserOption}}
        @value={{@field.value}}
        @valueProperty="name"
      />
    </@Control>
  </template>
}
