import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import {
  mapEveryoneToLoggedInUsersIds,
  mapLoggedInUsersToEveryoneForStorage,
} from "discourse/lib/group-list-setting-aliasing";
import { settingGroupRecords } from "discourse/lib/setting-group-records";
import { splitString } from "discourse/lib/utilities";
import ListSetting from "discourse/select-kit/components/list-setting";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";

const TOKEN_SEPARATOR = "|";

export default class SettingFieldGroupList extends Component {
  @service site;
  @service siteSettings;

  get granularPermissionsEnabled() {
    return this.siteSettings
      .granular_anonymous_and_logged_in_groups_permissions;
  }

  get groupChoices() {
    const disallowed = splitString(
      this.args.definition.disallowed_groups,
      TOKEN_SEPARATOR
    );
    const groups = (this.site.groups || []).filter(
      (group) => !disallowed.includes(group.id.toString())
    );
    const groupsById = Object.fromEntries(
      groups.map((group) => [group.id.toString(), group])
    );

    return mapEveryoneToLoggedInUsersIds(
      groups.map((group) => group.id.toString()),
      this.granularPermissionsEnabled
    )
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
    return this.selectedIds.map(Number);
  }

  /** The held mandatory groups, which the new picker keeps from being removed. */
  get lockedGroupIds() {
    const mandatory = splitString(
      this.args.definition.mandatory_values,
      TOKEN_SEPARATOR
    );
    return this.heldGroupIds.filter((id) => mandatory.includes(String(id)));
  }

  get selectedIds() {
    const value = this.args.field.value;
    const ids = Array.isArray(value)
      ? value.map(String)
      : splitString(value, TOKEN_SEPARATOR);

    return mapEveryoneToLoggedInUsersIds(ids, this.granularPermissionsEnabled);
  }

  get storedValueReference() {
    const saved = this.args.definition.currentSavedValue;
    if (saved !== undefined) {
      return saved;
    }

    const value = this.args.field.value;
    return Array.isArray(value) ? value.join(TOKEN_SEPARATOR) : value;
  }

  @bind
  onChange(ids) {
    const storedIds = mapLoggedInUsersToEveryoneForStorage(
      ids ?? [],
      this.granularPermissionsEnabled,
      this.storedValueReference,
      TOKEN_SEPARATOR
    );

    this.args.field.set(storedIds.join(TOKEN_SEPARATOR));
  }

  /** Stores the picked group ids, as the legacy list does. */
  @bind
  onPickGroups(ids) {
    this.onChange(ids.map(String));
  }

  <template>
    <@field.Control>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectGroup
          @disabled={{@field.disabled}}
          @lockedValues={{this.lockedGroupIds}}
          @multiple={{true}}
          @onChange={{this.onPickGroups}}
          @options={{this.groupRecords}}
          @texts={{hash ariaLabel=@field.title}}
          @value={{this.heldGroupIds}}
        />
      {{else}}
        <ListSetting
          @choices={{this.groupChoices}}
          @mandatoryValues={{@definition.mandatory_values}}
          @nameProperty="name"
          @onChange={{this.onChange}}
          @options={{hash disabled=@field.disabled}}
          @settingName={{@definition.key}}
          @value={{this.selectedIds}}
          @valueProperty="id"
        />
      {{/if}}
    </@field.Control>
  </template>
}
