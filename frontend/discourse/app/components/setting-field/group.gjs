import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { splitString } from "discourse/lib/utilities";
import ComboBox from "discourse/select-kit/components/combo-box";

export default class SettingFieldGroup extends Component {
  @service site;

  get groupChoices() {
    const disallowed = splitString(this.args.definition.disallowed_groups, "|");

    return (this.site.groups || [])
      .filter((group) => !disallowed.includes(group.id.toString()))
      .map((group) => ({ name: group.name, id: group.id.toString() }));
  }

  get groupId() {
    return this.args.field.value?.toString();
  }

  @action
  onChange(groupId) {
    this.args.field.set(groupId ?? "");
  }

  <template>
    <@field.Control>
      <ComboBox
        @content={{this.groupChoices}}
        @onChange={{this.onChange}}
        @options={{hash clearable=true disabled=@field.disabled}}
        @value={{this.groupId}}
      />
    </@field.Control>
  </template>
}
