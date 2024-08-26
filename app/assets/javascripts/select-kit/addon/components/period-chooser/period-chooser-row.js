import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import DropdownSelectBoxRowComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-row";

@classNames("period-chooser-row")
export default class PeriodChooserRow extends DropdownSelectBoxRowComponent {
  @discourseComputed("rowName")
  title(rowName) {
    return I18n.t(`filters.top.${rowName || "this_week"}`).title;
  }
}
