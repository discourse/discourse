import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: ["group-members-dropdown"],

  selectKitOptions: {
    icon: "bars",
    showFullTitle: false
  },

  content: computed(function() {
    const items = [
      {
        id: "showAddMembersModal",
        name: I18n.t("groups.add_members.title"),
        icon: "user-plus"
      }
    ];

    if (this.currentUser.admin) {
      items.push({
        id: "showBulkAddModal",
        name: I18n.t("admin.groups.bulk_add.title"),
        icon: "users"
      });
    }

    return items;
  })
});
