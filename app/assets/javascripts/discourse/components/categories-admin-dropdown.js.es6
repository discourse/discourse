import DropdownSelectBoxComponent from "discourse/components/dropdown-select-box";
import { iconHTML } from "discourse-common/lib/icon-library";
import computed from "ember-addons/ember-computed-decorators";

export default DropdownSelectBoxComponent.extend({
  classNames: ["categories-admin-dropdown"],

  icon: `${iconHTML('bars')}${iconHTML('caret-down')}`.htmlSafe(),

  generatedHeadertext: null,

  @computed
  content() {
    const items = [
      {
        id: "create",
        text: I18n.t("category.create"),
        description: I18n.t("category.create_long"),
        icon: "plus"
      }
    ];

    const includeReorder = this.get("siteSettings.fixed_category_positions");
    if (includeReorder) {
      items.push({
        id: "reorder",
        text: I18n.t("categories.reorder.title"),
        description: I18n.t("categories.reorder.title_long"),
        icon: "random"
      });
    }

    return items;
  },

  actionNames: {
    create: "createCategory",
    reorder: "reorderCategories"
  },

  actions: {
    onSelectRow(content) {
      this._super(content);

      this.sendAction(`actionNames.${this.get("value")}`);
      this.set("value", null);
    }
  }
});
