/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import { AUTO_GROUPS } from "discourse/lib/constants";
import ListSetting from "discourse/select-kit/components/list-setting";

// TODO (martin) Remove all this indirection when
// granular_anonymous_and_logged_in_groups_permissions is Permanent
const EVERYONE_ID = AUTO_GROUPS.everyone.id.toString();
const LOGGED_IN_USERS_ID = AUTO_GROUPS.logged_in_users.id.toString();

function normalizeIds(ids) {
  return ids.map((id) => id.toString());
}

function mapEveryoneToLoggedInUsersIds(ids, granularPermissionsEnabled) {
  ids = normalizeIds(ids);

  if (!granularPermissionsEnabled || !ids.includes(EVERYONE_ID)) {
    return ids;
  }

  return [
    ...new Set(ids.map((id) => (id === EVERYONE_ID ? LOGGED_IN_USERS_ID : id))),
  ];
}

function mapLoggedInUsersToEveryoneForStorage(
  ids,
  granularPermissionsEnabled,
  storedValue,
  tokenSeparator
) {
  if (!granularPermissionsEnabled) {
    return normalizeIds(ids);
  }

  const storedIds = normalizeIds(
    (storedValue || "").split(tokenSeparator).filter(Boolean)
  );

  if (
    !storedIds.includes(EVERYONE_ID) ||
    storedIds.includes(LOGGED_IN_USERS_ID)
  ) {
    return normalizeIds(ids);
  }

  return [
    ...new Set(
      normalizeIds(ids).map((id) =>
        id === LOGGED_IN_USERS_ID ? EVERYONE_ID : id
      )
    ),
  ];
}

@tagName("")
export default class GroupList extends Component {
  @service siteSettings;

  tokenSeparator = "|";
  nameProperty = "name";
  valueProperty = "id";

  @computed(
    "site.groups",
    "setting.disallowed_groups",
    "siteSettings.granular_anonymous_and_logged_in_groups_permissions"
  )
  get groupChoices() {
    const disallowed = (this.setting?.disallowed_groups || "")
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
        return group ? { name: group.name, id } : null;
      })
      .filter(Boolean);
  }

  @computed(
    "value",
    "siteSettings.granular_anonymous_and_logged_in_groups_permissions"
  )
  get settingValue() {
    const ids = (this.value || "").split(this.tokenSeparator).filter(Boolean);
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
      this.setting?.value,
      this.tokenSeparator
    );
    const storedValue = ids.join(this.tokenSeparator);

    if (this.changeValueCallback) {
      this.changeValueCallback(storedValue);
    } else {
      this.set("value", storedValue);
    }
  }

  <template>
    <div ...attributes>
      <ListSetting
        @value={{this.settingValue}}
        @choices={{this.groupChoices}}
        @settingName="name"
        @mandatoryValues={{this.setting.mandatory_values}}
        @nameProperty={{this.nameProperty}}
        @valueProperty={{this.valueProperty}}
        @onChange={{this.onChangeGroupListSetting}}
      />
    </div>
  </template>
}
