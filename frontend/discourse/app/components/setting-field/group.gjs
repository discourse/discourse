import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import { splitString } from "discourse/lib/utilities";
import ComboBox from "discourse/select-kit/components/combo-box";
import SiteService from "discourse/services/site";

export default class SettingFieldGroup extends Component {
  @service(() => SiteService) site;

  get groupChoices() {
    const disallowed = splitString(this.args.definition.disallowed_groups, "|");

    return (this.site.groups || [])
      .filter((group) => !disallowed.includes(group.id.toString()))
      .map((g) => {
        const name = g.name === "everyone" ? "everyone (legacy)" : g.name;
        return { name, id: g.id.toString() };
      });
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
