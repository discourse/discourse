import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DSegmentedControl from "discourse/components/d-segmented-control";
import { i18n } from "discourse-i18n";
import CustomDateRangeModal from "../modal/custom-date-range";

export const PERIOD_LAST_7_DAYS = "last_7_days";
export const PERIOD_LAST_30_DAYS = "last_30_days";
export const PERIOD_LAST_3_MONTHS = "last_3_months";
export const PERIOD_CUSTOM = "custom";

export const DEFAULT_PERIOD = PERIOD_LAST_30_DAYS;

export const VALID_PERIODS = [
  PERIOD_LAST_7_DAYS,
  PERIOD_LAST_30_DAYS,
  PERIOD_LAST_3_MONTHS,
  PERIOD_CUSTOM,
];

export function calculatePresetStartDate(period) {
  const today = moment();
  switch (period) {
    case PERIOD_LAST_7_DAYS:
      return today.subtract(7, "days").startOf("day").toDate();
    case PERIOD_LAST_3_MONTHS:
      return today.subtract(3, "months").startOf("day").toDate();
    case PERIOD_LAST_30_DAYS:
    default:
      return today.subtract(30, "days").startOf("day").toDate();
  }
}

export default class DashboardDateRange extends Component {
  @service modal;

  get isCustom() {
    return this.args.period === PERIOD_CUSTOM;
  }

  get customLabel() {
    if (!this.isCustom || !this.args.startDate || !this.args.endDate) {
      return i18n("admin.dashboard.period.custom");
    }

    return i18n("admin.dashboard.period.custom_range", {
      start: moment(this.args.startDate).format("MMM D"),
      end: moment(this.args.endDate).format("MMM D"),
    });
  }

  @action
  selectPeriod(value) {
    if (value === PERIOD_CUSTOM) {
      // custom is handled via handleClick to support re-opening the modal when
      // already-selected; skip preset state change here
      return;
    }
    this.args.setPeriod?.(value);
  }

  @action
  handleClick(value) {
    if (value === PERIOD_CUSTOM) {
      this.openCustomModal();
    }
  }

  openCustomModal() {
    this.modal.show(CustomDateRangeModal, {
      model: {
        startDate: this.args.startDate,
        endDate: this.args.endDate,
        setCustomDateRange: this.args.setCustomDateRange,
      },
    });
  }

  <template>
    <DSegmentedControl
      class="db-date-range"
      @name="dashboard-period"
      @value={{@period}}
      @onSelect={{this.selectPeriod}}
      @onClickItem={{this.handleClick}}
      @items={{array
        (hash
          value=PERIOD_LAST_7_DAYS
          label=(i18n "admin.dashboard.period.last_7_days")
        )
        (hash
          value=PERIOD_LAST_30_DAYS
          label=(i18n "admin.dashboard.period.last_30_days")
        )
        (hash
          value=PERIOD_LAST_3_MONTHS
          label=(i18n "admin.dashboard.period.last_3_months")
        )
        (hash
          value=PERIOD_CUSTOM
          label=this.customLabel
          class="db-date-range__custom"
        )
      }}
    />
  </template>
}
