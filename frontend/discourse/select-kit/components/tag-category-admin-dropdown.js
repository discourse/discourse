import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import renderTag from "discourse/lib/render-tag";
import DropdownSelectBoxComponent from "discourse/select-kit/components/dropdown-select-box";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import { i18n } from "discourse-i18n";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@classNames("tag-category-admin-dropdown")
@selectKitOptions({
  icons: ["wrench", "angle-down"],
  showFullTitle: false,
  autoFilterable: false,
  filterable: false,
  none: "select_kit.components.tag_category_admin_dropdown.title",
  focusAfterOnChange: false,
})
@pluginApiIdentifiers(["tag-category-admin-dropdown"])
export default class TagCategoryAdminDropdown extends DropdownSelectBoxComponent {
  @computed("category", "tag")
  get content() {
    return [
      {
        id: "editCategory",
        name: i18n(
          "select_kit.components.tag_category_admin_dropdown.edit_category"
        ),
        description: i18n(
          "select_kit.components.tag_category_admin_dropdown.edit_category_description",
          {
            badge: categoryBadgeHTML(this.category, {
              link: false,
              allowUncategorized: true,
            }),
          }
        ),
        icon: "folder-open",
      },
      {
        id: "editTag",
        name: i18n(
          "select_kit.components.tag_category_admin_dropdown.edit_tag"
        ),
        description: i18n(
          "select_kit.components.tag_category_admin_dropdown.edit_tag_description",
          { badge: renderTag(this.tag, { tagName: "span" }) }
        ),
        icon: "tag",
      },
    ];
  }

  _onChange(value, item) {
    if (item.onChange) {
      item.onChange(value, item);
    } else if (this.onChange) {
      this.onChange(value, item);
    }
  }
}
