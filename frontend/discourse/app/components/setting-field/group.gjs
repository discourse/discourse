import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { settingGroupRecords } from "discourse/lib/setting-group-records";
import { splitString } from "discourse/lib/utilities";
import ComboBox from "discourse/select-kit/components/combo-box";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";

export default class SettingFieldGroup extends Component {
  @service site;
  @service siteSettings;

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

  /** The offered groups as the new picker's records, under the names the setting shows. */
  get groupRecords() {
    return settingGroupRecords(this.groupChoices, this.site.groups);
  }

  /** The held group id as a number, or `null` for an unset setting. */
  get heldGroupId() {
    const id = this.groupId;
    return id ? Number(id) : null;
  }

  @action
  onChange(groupId) {
    this.args.field.set(groupId ?? "");
  }

  /** Stores the picked group's id as a string, or an empty string once cleared. */
  @action
  onPickGroup(groupId) {
    this.args.field.set(groupId === null ? "" : String(groupId));
  }

  <template>
    <@field.Control>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectGroup
          @clearable={{true}}
          @disabled={{@field.disabled}}
          @onChange={{this.onPickGroup}}
          @options={{this.groupRecords}}
          @texts={{hash ariaLabel=@field.title}}
          @value={{this.heldGroupId}}
        />
      {{else}}
        <ComboBox
          @content={{this.groupChoices}}
          @onChange={{this.onChange}}
          @options={{hash clearable=true disabled=@field.disabled}}
          @value={{this.groupId}}
        />
      {{/if}}
    </@field.Control>
  </template>
}
