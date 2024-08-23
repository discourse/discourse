import { action } from "@ember/object";
import { oneWay, readOnly } from "@ember/object/computed";
import { classNameBindings, classNames } from "@ember-decorators/component";
import I18n from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { selectKitOptions } from "select-kit/components/select-kit";

@classNames("period-chooser")
@classNameBindings("showPeriods::hidden")
@selectKitOptions({
  filterable: false,
  autoFilterable: false,
  fullDay: "fullDay",
  customStyle: true,
  headerComponent: "period-chooser/period-chooser-header",
  headerAriaLabel: I18n.t("period_chooser.aria_label"),
})
export default class PeriodChooser extends DropdownSelectBoxComponent {
  @oneWay("site.periods") content;
  @readOnly("period") value;

  valueProperty = null;
  nameProperty = null;
  showPeriods = true;

  modifyComponentForRow() {
    return "period-chooser/period-chooser-row";
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
