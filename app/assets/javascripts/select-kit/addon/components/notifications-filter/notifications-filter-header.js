import DropdownSelectBoxHeaderComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-header";
import discourseComputed from "discourse-common/utils/decorators";
import { fmt } from "discourse/lib/computed";
import layout from "select-kit/templates/components/notifications-filter/notifications-filter-header";

export default DropdownSelectBoxHeaderComponent.extend({
  layout,

  classNames: ["notifications-filter-header"],

  label: fmt("value", "user.user_notifications.filters.%@"),

  @discourseComputed("selectKit.isExpanded")
  caretIcon(isExpanded) {
    return isExpanded ? "caret-up" : "caret-down";
  },
});
