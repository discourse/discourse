import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@classNames("categories-admin-dropdown")
@selectKitOptions({
  icons: ["wrench", "caret-down"],
  showFullTitle: false,
  autoFilterable: false,
  filterable: false,
  none: "select_kit.components.categories_admin_dropdown.title",
  focusAfterOnChange: false,
})
@pluginApiIdentifiers(["categories-admin-dropdown"])
export default class CategoriesAdminDropdown extends DropdownSelectBoxComponent {
  @computed
  get content() {
    const items = [
      {
        id: "create",
        name: i18n("category.create"),
        description: i18n("category.create_long"),
        icon: "plus",
      },
    ];

    items.push({
      id: "reorder",
      name: i18n("categories.reorder.title"),
      description: i18n("categories.reorder.title_long"),
      icon: "shuffle",
    });

    return items;
  }

  _onChange(value, item) {
    if (item.onChange) {
      item.onChange(value, item);
    } else if (this.onChange) {
      this.onChange(value, item);
    }
  }
}
