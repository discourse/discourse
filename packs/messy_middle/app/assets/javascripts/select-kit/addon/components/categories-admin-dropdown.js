import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import { computed } from "@ember/object";
import { setting } from "discourse/lib/computed";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["categories-admin-dropdown"],
  classNames: ["categories-admin-dropdown"],
  fixedCategoryPositions: setting("fixed_category_positions"),

  selectKitOptions: {
    icons: ["wrench", "caret-down"],
    showFullTitle: false,
    autoFilterable: false,
    filterable: false,
    none: "select_kit.components.categories_admin_dropdown.title",
  },

  content: computed(function () {
    const items = [
      {
        id: "create",
        name: I18n.t("category.create"),
        description: I18n.t("category.create_long"),
        icon: "plus",
      },
    ];

    if (this.fixedCategoryPositions) {
      items.push({
        id: "reorder",
        name: I18n.t("categories.reorder.title"),
        description: I18n.t("categories.reorder.title_long"),
        icon: "random",
      });
    }

    return items;
  }),

  _onChange(value, item) {
    if (item.onChange) {
      item.onChange(value, item);
    } else if (this.attrs.onChange) {
      this.attrs.onChange(value, item);
    }
  },
});
