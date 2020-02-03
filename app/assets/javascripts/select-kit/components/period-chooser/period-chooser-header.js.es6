import DropdownSelectBoxHeaderComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-header";
import discourseComputed from "discourse-common/utils/decorators";

export default DropdownSelectBoxHeaderComponent.extend({
  layoutName:
    "select-kit/templates/components/period-chooser/period-chooser-header",
  classNames: ["period-chooser-header"],

  @discourseComputed("selectKit.isExpanded")
  caretIcon(isExpanded) {
    return isExpanded ? "caret-up" : "caret-down";
  }
});
