import DropdownSelectBoxComponent from "select-box-kit/components/dropdown-select-box";
import { iconHTML } from "discourse-common/lib/icon-library";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";

export default DropdownSelectBoxComponent.extend({
  classNames: "categories-admin-dropdown",
  actionNames: { create: "createCategory", reorder: "reorderCategories" },

  @on("didReceiveAttrs")
  _setComponentOptions() {
    this.set("headerComponentOptions", Ember.Object.create({
      shouldDisplaySelectedName: false,
      icon: `${iconHTML('bars')}${iconHTML('caret-down')}`.htmlSafe(),
    }));
  },

  @computed
  content() {
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

  actions: {
    onSelect(value) {
      value = this.defaultOnSelect(value);

      this.sendAction(`actionNames.${value}`);
      this.set("value", null);
    }
  }
});
