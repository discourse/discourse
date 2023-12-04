import discourseComputed from "discourse-common/utils/decorators";
import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";

export default ComboBoxSelectBoxHeaderComponent.extend({
  classNames: ["category-drop-header"],

  @discourseComputed("selectedContent.color")
  categoryBackgroundColor(categoryColor) {
    return categoryColor || "#e9e9e9";
  },

  @discourseComputed("selectedContent.text_color")
  categoryTextColor(categoryTextColor) {
    return categoryTextColor || "#333";
  },
});
