import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: "group-members-dropdown",
  headerIcon: ["bars", "caret-down"],
  showFullTitle: false,
  allowInitialValueMutation: false,
  autoHighlight() {},

  computeContent() {
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
  },

  mutateValue(value) {
    this.sendAction(value);
  }
});
