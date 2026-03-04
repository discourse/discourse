import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import periodTitle from "discourse/helpers/period-title";
import DropdownSelectBoxRowComponent from "discourse/select-kit/components/dropdown-select-box/dropdown-select-box-row";
import { i18n } from "discourse-i18n";

@classNames("period-chooser-row")
export default class PeriodChooserRow extends DropdownSelectBoxRowComponent {
  @computed("rowName")
  get title() {
    return i18n(`filters.top.${this.rowName || "this_week"}`).title;
  }

  <template>
    <span class="selection-indicator"></span>

    <span class="period-title">
      {{periodTitle
        this.rowValue
        showDateRange=true
        fullDay=this.selectKit.options.fullDay
      }}
    </span>
  </template>
}
