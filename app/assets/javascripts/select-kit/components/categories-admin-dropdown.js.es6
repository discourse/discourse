import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { computed } from "@ember/object";
import { setting } from "discourse/lib/computed";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["categories-admin-dropdown"],
  classNames: ["categories-admin-dropdown"],
  fixedCateoryPositions: setting("fixed_category_positions"),

  selectKitOptions: {
    icon: "bars",
    showFullTitle: false,
    autoFilterable: false,
    filterable: false
  },

  content: computed(function() {
    const items = [
      {
        id: "create",
        name: I18n.t("category.create"),
        description: I18n.t("category.create_long"),
        icon: "plus"
      }
    ];

    if (this.fixedCateoryPositions) {
      items.push({
        id: "reorder",
        name: I18n.t("categories.reorder.title"),
        description: I18n.t("categories.reorder.title_long"),
        icon: "random"
      });
    }

    return items;
  })
});
