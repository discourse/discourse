import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DashboardDateRangePicker from "discourse/admin/components/dashboard/date-range-picker";
import {
  ALL_PRESETS,
  DEFAULT_PERIOD,
  formatRange,
  PERIOD_CUSTOM,
  PRESET_LABEL_KEYS,
} from "discourse/admin/lib/dashboard-date-range";
import DMenu from "discourse/float-kit/components/d-menu";
import { i18n } from "discourse-i18n";

export default class DashboardDateRange extends Component {
  get triggerLabel() {
    const { period, startDate, endDate } = this.args;
    if (PRESET_LABEL_KEYS[period]) {
      return i18n(PRESET_LABEL_KEYS[period]);
    }
    if (period === PERIOD_CUSTOM && startDate && endDate) {
      return formatRange(startDate, endDate);
    }
    return i18n(PRESET_LABEL_KEYS[DEFAULT_PERIOD]);
  }

  get presets() {
    return ALL_PRESETS.map((id) => ({
      id,
      label: i18n(PRESET_LABEL_KEYS[id]),
    }));
  }

  get activePreset() {
    return PRESET_LABEL_KEYS[this.args.period] ? this.args.period : null;
  }

  @action
  handleApply(close, { preset, from, to }) {
    if (preset) {
      this.args.setPeriod?.(preset);
    } else {
      this.args.setCustomDateRange?.(from, to);
    }
    close();
  }

  <template>
    <DMenu
      @identifier="db-date-range-menu"
      @triggerClass="btn-default db-date-range__trigger"
      @modalForMobile={{true}}
      @placement="bottom-end"
      @maxWidth={{800}}
      @contentClass="db-date-range__popover"
      @icon="calendar-days"
      @label={{this.triggerLabel}}
    >
      <:content as |args|>
        <DashboardDateRangePicker
          @from={{@startDate}}
          @to={{@endDate}}
          @presets={{this.presets}}
          @activePreset={{this.activePreset}}
          @onApply={{fn this.handleApply args.close}}
          @onCancel={{args.close}}
        />
      </:content>
    </DMenu>
  </template>
}
