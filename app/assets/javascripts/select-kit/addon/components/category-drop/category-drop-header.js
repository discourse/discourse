import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";

@classNames("category-drop-header")
export default class CategoryDropHeader extends ComboBoxSelectBoxHeaderComponent {
  @discourseComputed("selectedContent.color")
  categoryBackgroundColor(categoryColor) {
    return categoryColor || "#e9e9e9";
  }

  @discourseComputed("selectedContent.text_color")
  categoryTextColor(categoryTextColor) {
    return categoryTextColor || "#333";
  }
}
