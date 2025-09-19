import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
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
      name: i18n("groups.members.remove_members"),
      description: i18n("groups.members.remove_members_description"),
      icon: "user-xmark",
    });

    if (this.currentUser.staff) {
      if (this.bulkSelection.some((m) => !m.primary)) {
        items.push({
          id: "setPrimary",
          name: i18n("groups.members.make_all_primary"),
          description: i18n("groups.members.make_all_primary_description"),
          icon: "id-card",
        });
      }

      if (this.bulkSelection.some((m) => m.primary)) {
        items.push({
          id: "unsetPrimary",
          name: i18n("groups.members.remove_all_primary"),
          description: i18n("groups.members.remove_all_primary_description"),
          icon: "id-card",
        });
      }
    }

    return items;
  }
}
