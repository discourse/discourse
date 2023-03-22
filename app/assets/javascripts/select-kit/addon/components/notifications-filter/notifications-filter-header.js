import DropdownSelectBoxHeaderComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-header";
import discourseComputed from "discourse-common/utils/decorators";
import { fmt } from "discourse/lib/computed";

export default DropdownSelectBoxHeaderComponent.extend({
  classNames: ["notifications-filter-header"],
  label: fmt("value", "user.user_notifications.filters.%@"),

  @discourseComputed("selectKit.isExpanded")
  caretIcon(isExpanded) {
    return isExpanded ? "caret-up" : "caret-down";
  }
});
