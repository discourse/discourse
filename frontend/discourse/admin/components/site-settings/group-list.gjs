import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  mapEveryoneToLoggedInUsersIds,
  mapLoggedInUsersToEveryoneForStorage,
} from "discourse/lib/group-list-setting-aliasing";
import { settingGroupRecords } from "discourse/lib/setting-group-records";
import ListSetting from "discourse/select-kit/components/list-setting";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";

export default class GroupList extends Component {
  @service site;
  @service siteSettings;

  tokenSeparator = "|";
  nameProperty = "name";
  valueProperty = "id";

  get groupChoices() {
    const disallowed = (this.args.setting?.disallowed_groups || "")
      .split("|")
      .filter(Boolean);
    const groups = (this.site.groups || []).filter(
      (g) => !disallowed.includes(g.id.toString())
    );
    const groupsById = Object.fromEntries(
      groups.map((g) => [g.id.toString(), g])
    );
    const choiceIds = mapEveryoneToLoggedInUsersIds(
      groups.map((g) => g.id.toString()),
      this.siteSettings.granular_anonymous_and_logged_in_groups_permissions
    );

    return choiceIds
      .map((id) => {
        const group = groupsById[id];
        const name =
          group.name === "everyone" ? "everyone (legacy)" : group.name;
        return group ? { name, id } : null;
      })
      .filter(Boolean);
  }

  /** The offered groups as the new picker's records, under the names the setting shows. */
  get groupRecords() {
    return settingGroupRecords(this.groupChoices, this.site.groups);
  }

  /** The held group ids as numbers, for the new picker. */
  get heldGroupIds() {
    return this.settingValue.map(Number);
  }

  /** The held mandatory groups, which the new picker keeps from being removed. */
  get lockedGroupIds() {
    const mandatory = (this.args.setting?.mandatory_values || "")
      .split(this.tokenSeparator)
      .filter(Boolean);
    return this.heldGroupIds.filter((id) => mandatory.includes(String(id)));
  }

  get settingValue() {
    const ids = (this.args.value || "")
      .split(this.tokenSeparator)
      .filter(Boolean);
    return mapEveryoneToLoggedInUsersIds(
      ids,
      this.siteSettings.granular_anonymous_and_logged_in_groups_permissions
    );
  }

  @action
  onChangeGroupListSetting(value) {
    const ids = mapLoggedInUsersToEveryoneForStorage(
      value,
      this.siteSettings.granular_anonymous_and_logged_in_groups_permissions,
      this.args.setting?.value,
      this.tokenSeparator
    );

    this.args.changeValueCallback(ids.join(this.tokenSeparator));
  }

  /** Stores the picked group ids, as the legacy list does. */
  @action
  onPickGroups(ids) {
    this.onChangeGroupListSetting(ids.map(String));
  }

  <template>
    <div ...attributes>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectGroup
          @lockedValues={{this.lockedGroupIds}}
          @multiple={{true}}
          @onChange={{this.onPickGroups}}
          @options={{this.groupRecords}}
          @texts={{hash ariaLabel=@label}}
          @value={{this.heldGroupIds}}
        />
      {{else}}
        <ListSetting
          @choices={{this.groupChoices}}
          @mandatoryValues={{@setting.mandatory_values}}
          @nameProperty={{this.nameProperty}}
          @onChange={{this.onChangeGroupListSetting}}
          @settingName="name"
          @value={{this.settingValue}}
          @valueProperty={{this.valueProperty}}
        />
      {{/if}}
    </div>
  </template>
}
