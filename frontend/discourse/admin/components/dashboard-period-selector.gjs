import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PeriodChooser from "discourse/select-kit/components/period-chooser";
import DButton from "discourse/ui-kit/d-button";
import CustomDateRangeModal from "../components/modal/custom-date-range";

export default class DashboardPeriodSelector extends Component {
  @service modal;

  availablePeriods = ["yearly", "quarterly", "monthly", "weekly"];

  @action
  openCustomDateRangeModal() {
    this.modal.show(CustomDateRangeModal, {
      model: {
        startDate: this.args.startDate,
        endDate: this.args.endDate,
        setCustomDateRange: this.args.setCustomDateRange,
      },
    });
  }

  <template>
    <div>
      <PeriodChooser
        @action={{@setPeriod}}
        @content={{this.availablePeriods}}
        @endDate={{@endDate}}
        @fullDay={{false}}
        @period={{@period}}
        @startDate={{@startDate}}
      />
      <DButton
        class="btn-default custom-date-range-button"
        @action={{this.openCustomDateRangeModal}}
        @icon="gear"
        @title="admin.dashboard.custom_date_range"
      />
    </div>
  </template>
}
