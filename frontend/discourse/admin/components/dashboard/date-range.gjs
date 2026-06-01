import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DashboardDateRangePicker, {
  ALL_PRESETS,
  formatRange,
  PRESET_LAST_3_MONTHS,
  PRESET_LAST_7_DAYS,
  PRESET_LAST_30_DAYS,
} from "discourse/admin/components/dashboard/date-range-picker";
import DMenu from "discourse/float-kit/components/d-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export const PERIOD_LAST_7_DAYS = PRESET_LAST_7_DAYS;
export const PERIOD_LAST_30_DAYS = PRESET_LAST_30_DAYS;
export const PERIOD_LAST_3_MONTHS = PRESET_LAST_3_MONTHS;
export const PERIOD_CUSTOM = "custom";

export const DEFAULT_PERIOD = PERIOD_LAST_30_DAYS;

export const VALID_PERIODS = [
  PERIOD_LAST_7_DAYS,
  PERIOD_LAST_30_DAYS,
  PERIOD_LAST_3_MONTHS,
  PERIOD_CUSTOM,
];

const TOP_TIER_PRESET_I18N_KEYS = {
  [PERIOD_LAST_7_DAYS]: "date_range_picker.presets.last_7_days",
  [PERIOD_LAST_30_DAYS]: "date_range_picker.presets.last_30_days",
  [PERIOD_LAST_3_MONTHS]: "date_range_picker.presets.last_3_months",
};

const TOP_TIER_PRESETS = new Set(Object.keys(TOP_TIER_PRESET_I18N_KEYS));

export function calculatePresetStartDate(period) {
  const today = moment();
  switch (period) {
    case PERIOD_LAST_7_DAYS:
      return today.subtract(6, "days").startOf("day").toDate();
    case PERIOD_LAST_3_MONTHS:
      return today.subtract(3, "months").add(1, "day").startOf("day").toDate();
    case PERIOD_LAST_30_DAYS:
    default:
      return today.subtract(29, "days").startOf("day").toDate();
  }
}

export default class DashboardDateRange extends Component {
  get triggerLabel() {
    const { period, startDate, endDate } = this.args;
    if (TOP_TIER_PRESET_I18N_KEYS[period]) {
      return i18n(TOP_TIER_PRESET_I18N_KEYS[period]);
    }
    if (period === PERIOD_CUSTOM && startDate && endDate) {
      return formatRange(startDate, endDate);
    }
    return i18n(TOP_TIER_PRESET_I18N_KEYS[DEFAULT_PERIOD]);
  }

  @action
  handleApply(close, { preset, from, to }) {
    if (preset && TOP_TIER_PRESETS.has(preset)) {
      this.args.setPeriod?.(preset);
    } else {
      this.args.setCustomDateRange?.(from, to);
    }
    close();
  }

  <template>
    <DMenu
      @identifier="db-date-range-menu"
      @triggerClass="db-date-range__trigger"
      @modalForMobile={{true}}
      @placement="bottom-end"
      @maxWidth={{680}}
      @contentClass="db-date-range__popover"
    >
      <:trigger>
        {{dIcon "calendar-days"}}
        <span class="db-date-range__trigger-label">{{this.triggerLabel}}</span>
      </:trigger>
      <:content as |args|>
        <DashboardDateRangePicker
          @from={{@startDate}}
          @to={{@endDate}}
          @presets={{ALL_PRESETS}}
          @onApply={{fn this.handleApply args.close}}
          @onCancel={{args.close}}
        />
      </:content>
    </DMenu>
  </template>
}
