/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class CustomDateRange extends Component {
  @tracked startDate = this.args.model.startDate;
  @tracked endDate = this.args.model.endDate;

  @action
  onChangeDateRange(range) {
    this.startDate = range.from;
    this.endDate = range.to;
  }

  @action
  updateDateRange() {
    this.args.model.setCustomDateRange(this.startDate, this.endDate);
    this.args.closeModal();
  }

  <template>
    <DModal
      class="custom-date-range-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "admin.dashboard.reports.dates"}}
    >
      <:body>
        <DDateTimeInputRange
          @from={{this.startDate}}
          @onChange={{this.onChangeDateRange}}
          @showFromTime={{false}}
          @showToTime={{false}}
          @to={{this.endDate}}
        />
      </:body>
      <:footer>
        <DButton
          @action={{this.updateDateRange}}
          @icon="arrows-rotate"
          @label="admin.dashboard.reports.refresh_report"
        />
      </:footer>
    </DModal>
  </template>
}
