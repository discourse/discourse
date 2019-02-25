import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["tags-admin-dropdown"],
  classNames: "tags-admin-dropdown",
  showFullTitle: false,
  allowInitialValueMutation: false,
  headerIcon: ["bars", "caret-down"],
  actionsMapping: null,

  autoHighlight() {},

  computeContent() {
    const items = [
      {
        id: "manageGroups",
        name: I18n.t("tagging.manage_groups"),
        description: I18n.t("tagging.manage_groups_description"),
        icon: "wrench",
        __sk_row_type: "noopRow"
      },
      {
        id: "uploadTags",
        name: I18n.t("tagging.upload"),
        description: I18n.t("tagging.upload_description"),
        icon: "upload",
        __sk_row_type: "noopRow"
      },
      {
        id: "deleteUnusedTags",
        name: I18n.t("tagging.delete_unused"),
        description: I18n.t("tagging.delete_unused_description"),
        icon: "trash",
        __sk_row_type: "noopRow"
      }
    ];

    return items;
  },

  actions: {
    onSelect(id) {
      const action = this.get("actionsMapping")[id];

      if (action) {
        action();
      }
    }
  }
});
