import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["group-member-dropdown"],
  classNames: ["group-member-dropdown"],

  selectKitOptions: {
    icon: "wrench",
    showFullTitle: false,
  },

  content: computed("member.owner", "member.primary", function () {
    const items = [
      {
        id: "removeMember",
        name: I18n.t("groups.members.remove_member"),
        description: I18n.t("groups.members.remove_member_description", {
          username: this.get("member.username"),
        }),
        icon: "user-times",
      },
    ];

    if (this.canAdminGroup) {
      if (this.member.owner) {
        items.push({
          id: "removeOwner",
          name: I18n.t("groups.members.remove_owner"),
          description: I18n.t("groups.members.remove_owner_description", {
            username: this.get("member.username"),
          }),
          icon: "shield-alt",
        });
      } else {
        items.push({
          id: "makeOwner",
          name: I18n.t("groups.members.make_owner"),
          description: I18n.t("groups.members.make_owner_description", {
            username: this.get("member.username"),
          }),
          icon: "shield-alt",
        });
      }
    } else if (this.canEditGroup && !this.member.owner) {
      items.push({
        id: "makeOwner",
        name: I18n.t("groups.members.make_owner"),
        description: I18n.t("groups.members.make_owner_description", {
          username: this.get("member.username"),
        }),
        icon: "shield-alt",
      });
    }

    if (this.currentUser.staff) {
      if (this.member.primary) {
        items.push({
          id: "removePrimary",
          name: I18n.t("groups.members.remove_primary"),
          description: I18n.t("groups.members.remove_primary_description", {
            username: this.get("member.username"),
          }),
          icon: "id-card",
        });
      } else {
        items.push({
          id: "makePrimary",
          name: I18n.t("groups.members.make_primary"),
          description: I18n.t("groups.members.make_primary_description", {
            username: this.get("member.username"),
          }),
          icon: "id-card",
        });
      }
    }

    return items;
  }),
});
