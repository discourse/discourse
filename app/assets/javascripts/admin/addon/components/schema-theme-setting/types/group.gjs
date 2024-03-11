import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Group from "discourse/models/group";
import GroupChooser from "select-kit/components/group-chooser";

export default class SchemaThemeSettingTypeGroup extends Component {
  @tracked value;
  @tracked groups;

  constructor() {
    super(...arguments);
    this.value = this.args.value;
    Group.findAll().then((groups) => {
      this.groups = groups;
    });
  }

  @action
  onInput(newVal) {
    this.value = newVal;
    this.args.onChange(newVal);
  }

  <template>
    <GroupChooser
      @content={{this.groups}}
      @value={{this.value}}
      @onChange={{this.onInput}}
    />
  </template>
}
