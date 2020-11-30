import DropdownSelectBoxHeaderComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-header";
import discourseComputed from "discourse-common/utils/decorators";
import layout from "select-kit/templates/components/period-chooser/period-chooser-header";

export default DropdownSelectBoxHeaderComponent.extend({
  layout,
  classNames: ["period-chooser-header"],

  @discourseComputed("selectKit.isExpanded")
  caretIcon(isExpanded) {
    return isExpanded ? "caret-up" : "caret-down";
  },
});
