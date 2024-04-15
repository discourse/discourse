import discourseComputed from "discourse-common/utils/decorators";
import DropdownSelectBoxHeaderComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-header";

export default DropdownSelectBoxHeaderComponent.extend({
  classNames: ["period-chooser-header", "btn-flat"],

  @discourseComputed("selectKit.isExpanded")
  caretIcon(isExpanded) {
    return isExpanded ? "caret-up" : "caret-down";
  },
});
