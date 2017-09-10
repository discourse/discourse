import DropdownSelectBoxComponent from "discourse/components/dropdown-select-box";
import { iconHTML } from "discourse-common/lib/icon-library";
import computed from "ember-addons/ember-computed-decorators";
import { observes } from "ember-addons/ember-computed-decorators";

export default DropdownSelectBoxComponent.extend({
  classNames: ["categories-admin-dropdown"],

  icon: `${iconHTML('bars')}${iconHTML('caret-down')}`.htmlSafe(),

  generatedHeadertext: null,

  fullWidthOnMobile: true,

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

  @observes("value")
  _didSelectRow() {
    this.sendAction(`actionNames.${this.get("value")}`);
    this.set("value", null);
  },

  @computed
  templateForRow: function() {
    return (rowComponent) => {
      const content = rowComponent.get("content");

      return `
        <div class="icons">${iconHTML(content.icon)}</div>
        <div class="texts">
          <span class="title">${Handlebars.escapeExpression(content.text)}</span>
          <span class="desc">${Handlebars.escapeExpression(content.description)}</span>
        </div>
      `;
    };
  }
});
