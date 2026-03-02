import { tracked } from "@glimmer/tracking";
import { action, computed } from "@ember/object";
import { classNameBindings, classNames } from "@ember-decorators/component";
import DropdownSelectBoxComponent from "discourse/select-kit/components/dropdown-select-box";
import { selectKitOptions } from "discourse/select-kit/components/select-kit";
import { i18n } from "discourse-i18n";
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
  startDate: "startDate",
  endDate: "endDate",
})
export default class PeriodChooser extends DropdownSelectBoxComponent {
  valueProperty = null;
  nameProperty = null;
  showPeriods = true;

  @tracked _contentOverride;

  @computed("site.periods")
  get content() {
    if (this._contentOverride !== undefined) {
      return this._contentOverride;
    }
    return this.site?.periods;
  }

  set content(value) {
    this._contentOverride = value;
  }

  @computed("period")
  get value() {
    return this.period;
  }

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
