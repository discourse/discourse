import Component from "@glimmer/component";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import {
  mapEveryoneToLoggedInUsersIds,
  mapLoggedInUsersToEveryoneForStorage,
} from "discourse/lib/group-list-setting-aliasing";
import { splitString } from "discourse/lib/utilities";
import ListSetting from "discourse/select-kit/components/list-setting";

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
        return group ? { name: group.name, id } : null;
      })
      .filter(Boolean);
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

  <template>
    <@field.Control>
      <ListSetting
        @value={{this.selectedIds}}
        @choices={{this.groupChoices}}
        @settingName={{@definition.key}}
        @mandatoryValues={{@definition.mandatory_values}}
        @nameProperty="name"
        @valueProperty="id"
        @onChange={{this.onChange}}
      />
    </@field.Control>
  </template>
}
