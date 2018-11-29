import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["tags-admin-dropdown"],
  classNames: "tags-admin-dropdown",
  showFullTitle: false,
  allowInitialValueMutation: false,
  headerIcon: ["bars", "caret-down"],

  autoHighlight() {},

  computeContent() {
    const items = [
      {
        id: "manageGroups",
        name: I18n.t("tagging.manage_groups"),
        description: I18n.t("tagging.manage_groups_description"),
        icon: "wrench"
      },
      {
        id: "uploadTags",
        name: I18n.t("tagging.upload"),
        description: I18n.t("tagging.upload_description"),
        icon: "upload"
      },
      {
        id: "deleteUnusedTags",
        name: I18n.t("tagging.delete_unused"),
        description: I18n.t("tagging.delete_unused_description"),
        icon: "trash"
      }
    ];

    return items;
  },

  actionNames: {
    manageGroups: "showTagGroups",
    uploadTags: "showUploader",
    deleteUnusedTags: "deleteUnused"
  },

  mutateValue(id) {
    this.sendAction(`actionNames.${id}`);
  }
});
