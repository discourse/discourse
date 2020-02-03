import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["group-member-dropdown"],
  classNames: ["group-member-dropdown"],

  selectKitOptions: {
    icon: "wrench",
    showFullTitle: false
  },

  content: computed("member.owner", function() {
    const items = [
      {
        id: "removeMember",
        name: I18n.t("groups.members.remove_member"),
        description: I18n.t("groups.members.remove_member_description", {
          username: this.get("member.username")
        }),
        icon: "user-times"
      }
    ];

    if (this.get("currentUser.admin")) {
      if (this.member.owner) {
        items.push({
          id: "removeOwner",
          name: I18n.t("groups.members.remove_owner"),
          description: I18n.t("groups.members.remove_owner_description", {
            username: this.get("member.username")
          }),
          icon: "shield-alt"
        });
      } else {
        items.push({
          id: "makeOwner",
          name: I18n.t("groups.members.make_owner"),
          description: I18n.t("groups.members.make_owner_description", {
            username: this.get("member.username")
          }),
          icon: "shield-alt"
        });
      }
    }

    return items;
  })
});
