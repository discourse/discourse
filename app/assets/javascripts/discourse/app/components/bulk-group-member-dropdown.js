import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["bulk-group-member-dropdown"],
  classNames: ["bulk-group-member-dropdown"],

  selectKitOptions: {
    icon: "cog",
    showFullTitle: false,
  },

  content: computed("bulkSelection.[]", function () {
    const items = [];

    items.push({
      id: "removeMembers",
      name: I18n.t("groups.members.remove_members"),
      description: I18n.t("groups.members.remove_members_description"),
      icon: "user-times",
    });

    if (this.bulkSelection.some((m) => !m.owner)) {
      items.push({
        id: "makeOwners",
        name: I18n.t("groups.members.make_owners"),
        description: I18n.t("groups.members.make_owners_description"),
        icon: "shield-alt",
      });
    }

    if (this.bulkSelection.some((m) => m.owner)) {
      items.push({
        id: "removeOwners",
        name: I18n.t("groups.members.remove_owners"),
        description: I18n.t("groups.members.remove_owners_description"),
        icon: "shield-alt",
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
  }),
});
