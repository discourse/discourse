import DropdownSelectBoxRowComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-row";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import layout from "select-kit/templates/components/period-chooser/period-chooser-row";

export default DropdownSelectBoxRowComponent.extend({
  layout,
  classNames: ["period-chooser-row"],

  @discourseComputed("rowName")
  title(rowName) {
    return I18n.t(`filters.top.${rowName || "this_week"}`).title;
  },
});
