import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";
import computed from "ember-addons/ember-computed-decorators";
import Category from "discourse/models/category";

export default ComboBoxSelectBoxHeaderComponent.extend({
  layoutName:
    "select-kit/templates/components/category-drop/category-drop-header",
  classNames: "category-drop-header",

  classNameBindings: ["categoryStyleClass"],
  categoryStyleClass: Ember.computed.alias("site.category_style"),

  @computed("computedContent.value", "computedContent.name")
  category(value, name) {
    if (Ember.isEmpty(value)) {
      const uncat = Category.findUncategorized();
      if (uncat && uncat.get("name") === name) {
        return uncat;
      }
    } else {
      return Category.findById(parseInt(value, 10));
    }
  },

  @computed("category.color")
  categoryBackgroundColor(categoryColor) {
    return categoryColor || "#e9e9e9";
  },

  @computed("category.text_color")
  categoryTextColor(categoryTextColor) {
    return categoryTextColor || "#333";
  },

  @computed("category", "categoryBackgroundColor", "categoryTextColor")
  categoryStyle(category, categoryBackgroundColor, categoryTextColor) {
    const categoryStyle = this.siteSettings.category_style;

    if (categoryStyle === "bullet") return;

    if (category) {
      if (categoryBackgroundColor || categoryTextColor) {
        let style = "";
        if (categoryBackgroundColor) {
          if (categoryStyle === "box") {
            style += `border-color: #${categoryBackgroundColor}; background-color: #${categoryBackgroundColor};`;
            if (categoryTextColor) {
              style += `color: #${categoryTextColor};`;
            }
          }
        }
        return style.htmlSafe();
      }
    }
  },

  didRender() {
    this._super(...arguments);

    this.$().attr("style", this.get("categoryStyle"));
    this.$(".caret-icon").attr("style", this.get("categoryStyle"));
  }
});
