import DropdownSelectBoxHeaderComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-header";
import discourseComputed from "discourse-common/utils/decorators";

export default DropdownSelectBoxHeaderComponent.extend({
  layoutName:
    "select-kit/templates/components/notifications-filter/notifications-filter-header",
  classNames: ["notifications-filter-header"],

  @discourseComputed("value")
  label(value) {
    return `user.user_notifications.filters.${value}`;
  },

  @discourseComputed("selectKit.isExpanded")
  caretIcon(isExpanded) {
    return isExpanded ? "caret-up" : "caret-down";
  }
});
