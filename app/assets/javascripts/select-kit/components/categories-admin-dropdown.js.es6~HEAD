import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { on } from "ember-addons/ember-computed-decorators";

export default DropdownSelectBoxComponent.extend({
  classNames: "categories-admin-dropdown",
  showFullTitle: false,
  allowInitialValueMutation: false,
  headerIcon: ["bars", "caret-down"],

  autoHighlight() {},

  @on("init")
  _setContent() {
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

    this.set("content", items);
  },

  mutateValue(value) {
    this.get(value)();
  }
});
