import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["categories-admin-dropdown"],
  classNames: "categories-admin-dropdown",
  showFullTitle: false,
  allowInitialValueMutation: false,
  headerIcon: ["bars"],

  autoHighlight() {},

  computeContent() {
    const items = [
      {
        id: "create",
        name: I18n.t("category.create"),
        description: I18n.t("category.create_long"),
        icon: "plus"
      }
    ];

    const includeReorder = this.get("siteSettings.fixed_category_positions");
    if (includeReorder) {
      items.push({
        id: "reorder",
        name: I18n.t("categories.reorder.title"),
        description: I18n.t("categories.reorder.title_long"),
        icon: "random"
      });
    }

    return items;
  },

  mutateValue(value) {
    this.get(value)();
  }
});
