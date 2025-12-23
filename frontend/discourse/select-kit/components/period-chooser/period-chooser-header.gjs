import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import periodTitle from "discourse/helpers/period-title";
import DropdownSelectBoxHeaderComponent from "discourse/select-kit/components/dropdown-select-box/dropdown-select-box-header";

@classNames("period-chooser-header", "btn-flat")
export default class PeriodChooserHeader extends DropdownSelectBoxHeaderComponent {
  @computed("selectKit.isExpanded")
  get caretIcon() {
    return this.selectKit?.isExpanded ? "caret-up" : "caret-down";
  }

  <template>
    <h2 class="selected-name" title={{this.title}}>
      {{periodTitle
        this.value
        showDateRange=true
        fullDay=this.selectKit.options.fullDay
      }}
    </h2>

    {{icon this.caretIcon class="caret-icon"}}
  </template>
}
