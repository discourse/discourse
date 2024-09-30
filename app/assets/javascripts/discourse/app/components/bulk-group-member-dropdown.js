import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import I18n from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("bulk-group-member-dropdown")
@selectKitOptions({
  icon: "gear",
  showFullTitle: false,
})
@pluginApiIdentifiers("bulk-group-member-dropdown")
export default class BulkGroupMemberDropdown extends DropdownSelectBoxComponent {
  @computed("bulkSelection.[]")
  get content() {
    const items = [];

    items.push({
      id: "removeMembers",
      name: I18n.t("groups.members.remove_members"),
      description: I18n.t("groups.members.remove_members_description"),
      icon: "user-xmark",
    });

    if (this.bulkSelection.some((m) => !m.owner)) {
      items.push({
        id: "makeOwners",
        name: I18n.t("groups.members.make_owners"),
        description: I18n.t("groups.members.make_owners_description"),
        icon: "shield-halved",
      });
    }

    if (this.bulkSelection.some((m) => m.owner)) {
      items.push({
        id: "removeOwners",
        name: I18n.t("groups.members.remove_owners"),
        description: I18n.t("groups.members.remove_owners_description"),
        icon: "shield-halved",
      });
    }

    if (this.currentUser.staff) {
      if (this.bulkSelection.some((m) => !m.primary)) {
        items.push({
          id: "setPrimary",
          name: I18n.t("groups.members.make_all_primary"),
          description: I18n.t("groups.members.make_all_primary_description"),
          icon: "id-card",
        });
      }

      if (this.bulkSelection.some((m) => m.primary)) {
        items.push({
          id: "unsetPrimary",
          name: I18n.t("groups.members.remove_all_primary"),
          description: I18n.t("groups.members.remove_all_primary_description"),
          icon: "id-card",
        });
      }
    }

    return items;
  }
}
