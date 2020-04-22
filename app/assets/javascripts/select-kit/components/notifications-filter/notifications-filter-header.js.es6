import DropdownSelectBoxHeaderComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-header";
import discourseComputed from "discourse-common/utils/decorators";

export default DropdownSelectBoxHeaderComponent.extend({
  layoutName:
    "select-kit/templates/components/notifications-filter/notifications-filter-header",
  classNames: ["period-chooser-header"],
  @discourseComputed("selectedContent")
  selectedContents(value){
    return value[0];
  },
  @discourseComputed("selectKit.isExpanded")
  caretIcon(isExpanded) {
    return isExpanded ? "caret-up" : "caret-down";
  }
});
