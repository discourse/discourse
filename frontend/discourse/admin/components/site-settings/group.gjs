/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import { settingGroupRecords } from "discourse/lib/setting-group-records";
import ComboBox from "discourse/select-kit/components/combo-box";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";

@tagName("")
export default class Group extends Component {
  @service siteSettings;

  @computed("site.groups", "setting.disallowed_groups")
  get groupChoices() {
    const disallowed = (this.setting?.disallowed_groups || "")
      .split("|")
      .filter(Boolean);

    return (this.site.groups || [])
      .filter((g) => !disallowed.includes(g.id.toString()))
      .map((g) => {
        const name = g.name === "everyone" ? "everyone (legacy)" : g.name;
        return { name, id: g.id.toString() };
      });
  }

  /** The offered groups as the new picker's records, under the names the setting shows. */
  get groupRecords() {
    return settingGroupRecords(this.groupChoices, this.site.groups);
  }

  /** The held group id as a number, or `null` for an unset setting. */
  get heldGroupId() {
    return this.value ? Number(this.value) : null;
  }

  @action
  onChange(value) {
    this.changeValueCallback?.(value ?? "");
  }

  /** Stores the picked group's id as a string, or an empty string once cleared. */
  @action
  onPickGroup(groupId) {
    this.changeValueCallback?.(groupId === null ? "" : String(groupId));
  }

  <template>
    <div ...attributes>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectGroup
          @clearable={{true}}
          @onChange={{this.onPickGroup}}
          @options={{this.groupRecords}}
          @texts={{hash ariaLabel=@label}}
          @value={{this.heldGroupId}}
        />
      {{else}}
        <ComboBox
          @content={{this.groupChoices}}
          @onChange={{this.onChange}}
          @options={{hash clearable=true}}
          @value={{@value}}
        />
      {{/if}}
    </div>
  </template>
}
