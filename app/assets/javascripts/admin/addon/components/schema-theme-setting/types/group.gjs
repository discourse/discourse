import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import Group from "discourse/models/group";
import GroupChooser from "select-kit/components/group-chooser";

export default class SchemaThemeSettingTypeGroup extends Component {
  @tracked value = this.args.value;
  @tracked groups = Group.findAll().then((groups) => {
    this.groups = groups;
  });

  @action
  onInput(newVal) {
    this.value = newVal[0];
    this.args.onChange(newVal[0]);
  }

  <template>
    <GroupChooser
      @content={{this.groups}}
      @value={{this.value}}
      @onChange={{this.onInput}}
      @options={{hash maximum=1}}
    />
  </template>
}
