import DropdownSelectBoxRowComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-row";
import discourseComputed from "discourse-common/utils/decorators";

export default DropdownSelectBoxRowComponent.extend({
  layoutName:
    "select-kit/templates/components/period-chooser/period-chooser-row",
  classNames: ["period-chooser-row"],

  @discourseComputed("rowName")
  title(rowName) {
    return I18n.t(`filters.top.${rowName || "this_week"}`).title;
  }
});
