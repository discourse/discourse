import { action } from "@ember/object";
import { oneWay, readOnly } from "@ember/object/computed";
import { classNameBindings, classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { selectKitOptions } from "select-kit/components/select-kit";
import PeriodChooserHeader from "./period-chooser/period-chooser-header";
import PeriodChooserRow from "./period-chooser/period-chooser-row";

@classNames("period-chooser")
@classNameBindings("showPeriods::hidden")
@selectKitOptions({
  filterable: false,
  autoFilterable: false,
  fullDay: "fullDay",
  customStyle: true,
  headerComponent: PeriodChooserHeader,
  headerAriaLabel: i18n("period_chooser.aria_label"),
})
export default class PeriodChooser extends DropdownSelectBoxComponent {
  @oneWay("site.periods") content;
  @readOnly("period") value;

  valueProperty = null;
  nameProperty = null;
  showPeriods = true;

  modifyComponentForRow() {
    return PeriodChooserRow;
  }

  @action
  _onChange(value) {
    if (this.action) {
      this.action(value);
    } else {
      this.onChange?.(value);
    }
  }
}
