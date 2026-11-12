import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import periodTitle from "discourse/helpers/period-title";
import DropdownSelectBoxHeaderComponent from "discourse/select-kit/components/dropdown-select-box/dropdown-select-box-header";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@classNames("period-chooser-header", "btn-flat")
export default class PeriodChooserHeader extends DropdownSelectBoxHeaderComponent {
  @computed("selectKit.isExpanded")
  get caretIcon() {
    return this.selectKit?.isExpanded ? "angle-up" : "angle-down";
  }

  <template>
    <h2 class="selected-name" title={{this.title}}>
      {{periodTitle
        this.value
        showDateRange=true
        fullDay=this.selectKit.options.fullDay
        startDate=this.selectKit.options.startDate
        endDate=this.selectKit.options.endDate
      }}
    </h2>

    {{dIcon this.caretIcon class="angle-icon"}}
  </template>
}
