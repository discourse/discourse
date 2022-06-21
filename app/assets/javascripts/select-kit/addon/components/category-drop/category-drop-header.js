import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";
import discourseComputed from "discourse-common/utils/decorators";
import layout from "select-kit/templates/components/category-drop/category-drop-header";
import { readOnly } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import { htmlSafe } from "@ember/template";

export default ComboBoxSelectBoxHeaderComponent.extend({
  layout,
  classNames: ["category-drop-header"],
  classNameBindings: ["categoryStyleClass"],
  categoryStyleClass: readOnly("site.category_style"),

  @discourseComputed("selectedContent.color")
  categoryBackgroundColor(categoryColor) {
    return categoryColor || "#e9e9e9";
  },

  @discourseComputed("selectedContent.text_color")
  categoryTextColor(categoryTextColor) {
    return categoryTextColor || "#333";
  },

  @discourseComputed(
    "selectedContent",
    "categoryBackgroundColor",
    "categoryTextColor"
  )
  categoryStyle(category, categoryBackgroundColor, categoryTextColor) {
    const categoryStyle = this.siteSettings.category_style;

    if (categoryStyle === "bullet") {
      return;
    }

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
        return htmlSafe(style);
      }
    }
  },

  didInsertElement() {
    this._super(...arguments);

    schedule("afterRender", () => {
      if (this.categoryStyle) {
        this.element.setAttribute("style", this.categoryStyle);
        this.element
          .querySelector(".caret-icon")
          .setAttribute("style", this.categoryStyle);
      }
    });
  },
});
