import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  mapEveryoneToLoggedInUsersIds,
  mapLoggedInUsersToEveryoneForStorage,
} from "discourse/lib/group-list-setting-aliasing";
import ListSetting from "discourse/select-kit/components/list-setting";

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

  <template>
    <div ...attributes>
      <ListSetting
        @choices={{this.groupChoices}}
        @mandatoryValues={{@setting.mandatory_values}}
        @nameProperty={{this.nameProperty}}
        @onChange={{this.onChangeGroupListSetting}}
        @settingName="name"
        @value={{this.settingValue}}
        @valueProperty={{this.valueProperty}}
      />
    </div>
  </template>
}
