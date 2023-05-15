import DropdownSelectBoxRowComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-row";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";

export default DropdownSelectBoxRowComponent.extend({
  classNames: ["period-chooser-row"],

  @discourseComputed("rowName")
  title(rowName) {
    return I18n.t(`filters.top.${rowName || "this_week"}`).title;
  },
});
