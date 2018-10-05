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
      }
    ];

    return items;
  },

  actionNames: {
    manageGroups: "showTagGroups"
  },

  mutateValue(id) {
    this.sendAction(`actionNames.${id}`);
  }
});
